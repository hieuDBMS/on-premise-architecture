package quality

def credentials
def url
def domain
def enableDebugHttpRequest
def metricKeys

def init() {
    this.credentials = conf.credentials['sonarqube']
    this.url = conf.sonarConfig.url
    this.enableDebugHttpRequest = conf.sonarConfig.get('enableDebugHttpRequest', false)
    this.metricKeys = conf.sonarConfig.metricKeys
}

def getQualitiGateByProject(sonarProjectKey) {
    def params = generateSonarWebApiParams([
        project: sonarProjectKey,
    ])
    def apiUrl = "${this.url}/api/qualitygates/get_by_project?${params}"
    response = callWebApi(apiUrl, "GET")
    responseJs = readJSON(text: response.content)
    return responseJs.get('name', '')
}

def getGrades(sonarProjectKey) {
    def params = generateSonarWebApiParams([
        component: sonarProjectKey,
        metricKeys: this.metricKeys.join(',')
    ])
    def apiUrl = "${this.url}/api/measures/component?${params}"
    response = callWebApi(apiUrl, "GET")
    resposneJs = readJSON(text: response.content)
    grades = resposneJs.component.measures.collectEntries { metric -> 
        if (metric.metric == 'security_hotspots') {
            [(metric.metric): metric.value]
        } else {
            [(metric.metric): getRatingLabel(metric.value)]
        }
    }
    return grades
}

def createProject(sonarProjectKey, sonarProjectName) {
    params = generateSonarWebApiParams([
        project: sonarProjectKey,
        name   : sonarProjectName,
    ])
    def apiUrl = "${this.url}/api/projects/create?${params}"
    response = callWebApi(apiUrl, "POST")
    responseJs = readJSON(text: response.content)
    return responseJs.get('components', [])
}

def getProject(sonarProjectKey) {
    def params = generateSonarWebApiParams([
        projects: sonarProjectKey,
    ])
    def apiUrl = "${this.url}/api/projects/search?${params}"
    response = callWebApi(apiUrl, "GET")
    responseJs = readJSON(text: response.content)
    project = responseJs.get('components', []) ? responseJs['components'][0] : null
    return project
}

def setQualityGateForProject(sonarProjectKey, qualityGateName) {
    def params = generateSonarWebApiParams([
        projectKey: sonarProjectKey,
        gateName: qualityGateName,
    ])
    def apiUrl = "${this.url}/api/qualitygates/select?${params}"
    response = callWebApi(apiUrl, "POST")
    return response 
}

def getDashboard(sonarProjectKey){
    return "${this.url}/dashboard?id=${sonarProjectKey}"
}

def getRatingLabel(rating){
    switch(rating){
        case '0.0': return '🤷‍♀️ No Data'
        case '1.0': return '💦 A (Excellent) '
        case '2.0': return '👍 B (Good)'
        case '3.0': return '🤷‍♂️ C (Average)'
        case '4.0': return '🐔 D (Poor)'
        case '5.0': return '🤡 E (Very Poor)'
    }
}

def generateSonarWebApiParams(paramsConfig) {
    def params = paramsConfig.collect { param, value -> 
        def encodedValue = java.net.URLEncoder.encode(value, "UTF-8")
        "${param}=${encodedValue}"
    }
    return params.join("&")
}

def callWebApi(String apiUrl, method, validResponseCodes = '100:399'){
    withCredentials([string(credentialsId: this.credentials, variable: 'PRIVATE_TOKEN')]) {
        return httpRequest(
            url: apiUrl,
            httpMode: method,
            customHeaders: [[name: 'Authorization', value: 'Bearer ' + PRIVATE_TOKEN]],
            ignoreSslErrors: true,
            acceptType: 'APPLICATION_JSON_UTF8',
            contentType: 'APPLICATION_JSON_UTF8',
            wrapAsMultipart: false,
            validResponseCodes: validResponseCodes,
            consoleLogResponseBody: this.enableDebugHttpRequest,
        )
    }
}