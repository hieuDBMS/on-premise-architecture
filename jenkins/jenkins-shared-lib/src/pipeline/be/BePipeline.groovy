#!/usr/bin/groovy
package pipeline.be

import jenkins.Jenkins
import pipeline.be.*
import pipeline.PipelineState
import utilities.notification.*
import quality.*

class BePipeline extends Jenkins {
    def cdPipeline
    def ciPipeline
    def qualityGate
    def buildStatus
    def imageTag
    def resultAnalysis 


    BePipeline(def jenkins){
        this.jenkins = jenkins
        this.cdPipeline = new CdPipeline(jenkins)
        this.ciPipeline = new CiPipeline(jenkins)
        this.qualityGate = new QualityGate()
        this.buildStatus = PipelineState.NOT_BUILT
        this.imageTag = 'UNKNOWN'
    }

    def run(String gitUrl, String cdRepoUrl, String deployEnv, String appName, String serviceName, String timeZoneId) {
        execute {
            try {
                this.qualityGate.init()
                this.imageTag = ciPipeline.commonStages(gitUrl, deployEnv)  
                this.resultAnalysis = this.qualityGate.sonarQubeAnalysisBE(appName, serviceName, 'gradle')
                ciPipeline.build(deployEnv, appName, serviceName)
                cdPipeline.commonStages(deployEnv, appName, serviceName, this.imageTag, cdRepoUrl)
                this.buildStatus = PipelineState.SUCCESS
            } catch (err) {
                this.buildStatus = PipelineState.FAILURE
                error jenkins.utils.getStackTrace(err)
            } finally {
                def qualityGateResult = "Scanning Fail"
                def gradeResult = "Scanning Fail"
                if (this.resultAnalysis != null ) {
                    qualityGateResult = resultAnalysis.qualityGate
                    gradeResult = resultAnalysis.grades
                }
                def project = appName + "-" + serviceName
                def props = [
                    'Build Status' : this.buildStatus.state,
                    'Build At:' : new Date().format("yyyy-MM-dd'T'HH:mm:ssXXX", TimeZone.getTimeZone(timeZoneId)),
                    'Image Tag' : this.imageTag,
                    'Job Name'     : env.JOB_NAME,
                    'Build Number' : env.BUILD_NUMBER,
                    'Triggered By' : env.BUILD_USER_ID ?: env.USER ?: 'SYSTEM',
                    'Quality Gate' : qualityGateResult,
                    'Grades' : gradeResult,
                    'Build URL'    : env.BUILD_URL,
                    'Sonar URL': this.qualityGate.sonarqube.getDashboard(project)
                ]
                Notification noti = new Notification(this.jenkins, props['Build URL'], props['Job Name'], props['Build Number'])
                // def recipients = [jenkins.conf.notification['email']]
                // Send Email
                // noti.sendEmail('Manager', recipients, props)
                // Send Lotuschat
                noti.sendLotus(props)
            }
        }
    }
}

