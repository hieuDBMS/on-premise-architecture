package quality

import quality.SonarQube

def sonarQubeEnv
def webhookCredential
def sonarScannerTool
def sonarCredential
def sonarqube
def scannerTimeout
def qualityGate
def grades
def qualityGateWay

def init() {
    this.sonarQubeEnv = conf.sonarConfig['sonarQubeEnv']
    this.webhookCredential = conf.credentials['sonarqube-webhook']
    this.sonarCredential = conf.credentials['sonarqube']
    this.scannerTimeout = conf.sonarConfig['scannerTimeout']
    this.qualityGateWay = conf.sonarConfig['qualityGateWay']
    this.sonarqube = new SonarQube()
    this.sonarqube.init()
}

def sonarQubeAnalysisBE (appName, serviceName, type) {
    def project = appName + '-' + serviceName
    stage("Quality Scanning") {
        // Check project exist or not
        if(this.sonarqube.getProject(project) == null) {
            // Create if not exist
            this.sonarqube.createProject(project, project)
            this.sonarqube.setQualityGateForProject(project, this.qualityGateWay)
        }
        switch (type) {
            case 'gradle':
                gradleBuild()
                break
            default:
                echo "⚠️ Unsupported build type: ${type}"
        }
        utils.yamlToProperties('sonar-project.yaml', 'sonar-project.properties')
        this.qualityGate = scanning(false)
        this.grades = this.sonarqube.getGrades(project)
    }
    return [
        qualityGate: qualityGate,
        grades: grades
    ]
}

def sonarQubeAnalysisFE (appName, serviceName, type = null) {
    def project = appName + '-' + serviceName
    stage("Quality Scanning") {
        // Check project exist or not
        if(this.sonarqube.getProject(project) == null) {
            // Create if not exist
            this.sonarqube.createProject(project, project)
            this.sonarqube.setQualityGateForProject(project, this.qualityGateWay)
        }
        switch (type) {
            default:
                echo "⚠️ Unsupported build type: ${type}"
        }
        utils.yamlToProperties('sonar-project.yaml', 'sonar-project.properties')
        this.qualityGate = scanning(false)
        this.grades = this.sonarqube.getGrades(project)
    }
    return [
        qualityGate: qualityGate,
        grades: grades
    ]
}

def gradleBuild(){
    sh '''
        chmod +x gradlew
        ./gradlew clean build
    '''
}

def scanning (isFaileOnError = false) {
    withSonarQubeEnv(credentialsId: this.sonarCredential, installationName: this.sonarQubeEnv) {
        sh 'sonar-scanner'
    }
    timeout(time: this.scannerTimeout, units: 'MINUTES') {
        def gate = waitForQualityGate()
        if (gate.status != 'OK') {
            def errorMessage = "Quality gate status: ${gate.status}."
            // if(isFaileOnError){
            //     error(errMessage)
            // } else {
            //     unstable(errMessage)
            // }
            return errorMessage
        } else {
            def successMessage = "Quality gate status: ${gate.status}."
            return successMessage
        }
    }
}