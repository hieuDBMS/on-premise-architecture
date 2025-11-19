package utilities.notification

import jenkins.Jenkins

class Notification extends Jenkins {
    Boolean enableDebug
    String buildUrl
    String jobName
    String buildNumber

    Notification(def jenkins, String buildUrl, String jobName, String buildNumber) {
        this.jenkins = jenkins
        this.buildUrl = buildUrl
        this.jobName = jobName
        this.buildNumber = buildNumber
        this.enableDebug = false
    }

    void sendEmail(String roleName, def recipients, Map<String, String> props){
        execute {
            String emailBody = libraryResource("emailTemplate/jenkinsAlertTemplateEmail.html")
            emailBody = emailBody.replace('$BUILD_URL', this.buildUrl)
            emailBody = emailBody.replace(
                '$ALERT_HEADER', 'Jenkins Build Review Request'
            )
            emailBody = emailBody.replace(
                '$ALERT_BODY', """
                    <p>Your role in this approval: <strong>${roleName}</strong></p>
                    <p>The deployment pipeline for <strong>${this.jobName}#${this.buildNumber}</strong> requires your interview.</p>
                    <p>Please review the build information below and take appropriate action.</p>
                """
            )
            List<String> tableItems = props.collect { key, value ->
                "<tr><td class=\"key\">${key}</td><td class=\"value\">${value}</td></tr>"
            }
            emailBody = emailBody.replace('$BUILD_INFO', tableItems.join('\n'))

            emailext(
                mimeType: 'text/html',
                body: emailBody,
                subject: "[INTERVIEW REQUIRED] ${this.jobName}#${this.buildNumber}",
                attachLog: true,
                to: recipients.join(',')
            )
        }
    }

    void sendDiscord(String roleName, String webHookUrl, Map<String, String> props, String timeZoneId = "UTC") {
        execute {
            def allFields = props.collect { key, value ->
                [
                    name : key.toString().capitalize(),
                    value: value.toString(),
                    inline: true
                ]
            }

            // Just one line to handle timezone
            def timestamp = new Date().format("yyyy-MM-dd'T'HH:mm:ssXXX", TimeZone.getTimeZone(timeZoneId))
            def buildStatus = props['Build Status'] ?: 'FAIL'
            def statusEmoji = buildStatus == 'SUCCESS' ? '✅' : '❌'
            def alertBodyText = buildStatus == 'SUCCESS' ? 
                'The pipeline completed successfully and all stages passed.' : 
                'The pipeline failed! Review the logs for details.'
            def statusColorInt = buildStatus == 'SUCCESS' ? 3066674 : 13844735 // Discord color
            
            def discordPayload = [
                embeds: [[
                    title      : "${statusEmoji} Jenkins Build ${buildStatus}",
                    description: "${alertBodyText}",
                    color      : statusColorInt,
                    fields     : allFields,
                    timestamp  : timestamp
                ]]
            ]
            def payloadJson = new groovy.json.JsonBuilder(discordPayload).toString()
            sh """
                curl -X POST "${webHookUrl}" \
                -H "Content-Type: application/json" \
                -d '${payloadJson}'
            """
            echo "Discord notification sent successfully"
        }
    }

    void sendLotus(Map<String, String> props) {
        execute {
            // Lấy các biến môi trường từ Jenkins
            def lotusChatApiUrl = this.jenkins.conf.notification.lotusChat.api_url
            def lotusChatChatId = this.jenkins.conf.notification.lotusChat.chat_id
            if (!lotusChatApiUrl || !lotusChatChatId) {
                this.jenkins.echo "WARNING: LOTUSCHAT_API_URL or LOTUSCHAT_CHAT_ID not set. Skipping LotusChat notification."
                return
            }

            // --- 1. Tạo chuỗi HTML từ props ---
            def status = props['Build Status'] ?: 'UNKNOWN'
            def iconMap = [
                'SUCCESS': '✅', 'FAILURE': '❌', 'UNSTABLE': '⚠️',
                'ABORTED': '🛑', 'STARTED': '▶️'
            ]
            def icon = iconMap.get(status.toUpperCase(), '❓')

            // Header
            def message = "${icon} <b>JENKINS BUILD ${status.toUpperCase()}</b>\n"

            // Process all fields
            props.each { key, value ->
                // Skip these special fields as we'll handle them separately
                if (key in ['Build URL', 'Sonar URL', 'Grades']) {
                    return // continue to next iteration
                }
                
                message += "<b>${key}:</b> ${value}\n"
            }

            // Grades section (with blank line before if exists)
            if (props.containsKey('Grades')) {
                def gradesValue = props['Grades']
                if (gradesValue instanceof Map) {
                    // Format grades as comma-separated string
                    def formattedGrades = gradesValue.collect { metric, grade ->
                        "${metric}: ${grade ?: 'N/A'}"
                    }.join(', ')
                    message += "\n<b>Grades:</b> ${formattedGrades}\n"
                } else {
                    message += "\n<b>Grades:</b> ${gradesValue}\n"
                }
            }

            // Build URL section (with blank line before and URL on next line if exists)
            if (props.containsKey('Build URL')) {
                message += "\n<b>🔗 Build URL:</b>\n${props['Build URL']}\n"
            }

            // Sonar URL section (with blank line before and URL on next line if exists)
            if (props.containsKey('Sonar URL')) {
                message += "\n<b>📊 Sonar URL:</b>\n${props['Sonar URL']}"
            }

            // --- 2. Gửi thông báo đến LotusChat ---
            
            // Prepare the message for the JSON payload
            def encodedMessage = message
                    .replaceAll('\\\\', '\\\\\\\\') // Escape backslashes
                    .replaceAll('"', '\\\\"')        // Escape double quotes
                    .replaceAll('\r', '')          // Remove carriage returns
                    .replaceAll('\n', '\\\\n')       // Escape newlines for JSON string literal

            lotusChatChatId.each { chatId -> 
                try {
                    def response = sh(
                        script: """
                            curl -X POST '${lotusChatApiUrl}' \\
                            -H 'Content-Type: application/json' \\
                            -d '{
                                "chat_id": "${chatId}",
                                "parse_mode": "HTML", 
                                "text": "${encodedMessage}"
                            }'
                        """,
                        returnStdout: true
                    ).trim()
                    echo "LotusChat notification sent successfully. Response: ${response}"
                } catch (Exception e) {
                    this.jenkins.echo "ERROR: Failed to send LotusChat notification: ${e.message}"
                }
            } 
        }
    }
}