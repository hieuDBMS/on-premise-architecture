package deploy.argocd

import pipeline.*
import vcs.*

def appName
def serviceName
def deployEnv
def cdRepoBranch
def pGit
def argocdBaseUrl
def syncTimeout
def cdServer
def revision

def init (String deployEnv, String appName, String serviceName){
    this.pGit = new Git()
    this.deployEnv = deployEnv
    this.appName = appName
    this.serviceName = serviceName

    this.argocdBaseUrl = conf.envConfigMap[deployEnv]['argocd']['url']
    this.cdRepoBranch = conf.envConfigMap[deployEnv]['branch']
    this.syncTimeout = (conf.envConfigMap[deployEnv]['argocd']).get('syncTimeout', '600')
    this.cdServer = conf.envConfigMap[deployEnv]['argocd']['server']
    this.revision = conf.envConfigMap[deployEnv]['argocd']['revision']
}

def deploy(imageTag, targetEnv, cdRepoUrl, timeZoneId = null, forceSyncOnly = false, cdFilePath = null, argocdApp = null) {
    def argocdAppName = argocdApp ?: ARGOCD_APPNAME(targetEnv)
    login()
    if (!forceSyncOnly) {
        updateCdRepo(imageTag, targetEnv, cdRepoUrl, cdFilePath, timeZoneId)
    }
    if (checkApplicationExist(argocdAppName)){
        forceSyncApp(argocdAppName)
    } else {
        createApplication(cdRepoUrl, cdFilePath, argocdAppName, targetEnv)
    }
    
}

def updateCdRepo(imageTag, targetEnv, cdRepoUrl, cdFilePath = null, timeZoneId){
    dir("cd_repo"){
        pGit.init()
        pGit.checkoutBranch(cdRepoUrl, this.cdRepoBranch)
        def filePathToUpdate = cdFilePath ?: getSubPath(targetEnv, serviceName)

        if (cdFilePath) {
            regexStr = replaceImageTagForFilePath(this.appName, this.serviceName, cdFilePath, imageTag, timeZoneId)
        } else {
            regexStr = replaceImageTag(this.appName, this.serviceName, filePathToUpdate, imageTag, timeZoneId)
        }

        try {
            pGit.commit(filePathToUpdate, "Jenkins CI update image tag: ${imageTag}")
            pGit.push(cdRepoUrl, this.cdRepoBranch)
        } catch (Exception e) {
            env.BUILD_STATUS = PipelineState.UNSTABLE.state
            msgArr = [
                    "Jenkins Bot is trying to replace content that matching regex \"${regexStr}\" in CD repo. But nothing to be updated, then there is no change in CD repo.",
                    "Please check details in:",
                    "  CD repo git URL: ${cdRepoUrl}",
                    "  Branch: ${this.cdRepoBranch}",
                    "  Sub path: ${filePathToUpdate}",
                    "  Tag: ${imageTag}"
            ]
            unstable(msgArr.join("\n"))
        }
        deleteDir()
    }
}

def getSubPath(targetEnv, serviceName) {
    return [targetEnv, serviceName].join("/")
// return serviceName
}

def replaceImageTagForFilePath(appName, serviceName, cdFilePath, newImageTag, enableReplaceDebug = true, timeZoneId) {
    def regexStr = getReplaceTagRegex(appName, serviceName)
    try {
        dir(cdFilePath) {
            def updateImageTag = "sed -E -i 's#${regexStr}#\\1${newImageTag}#g' values.yaml"
            sh(script: updateImageTag)
            def updateAppVersion = """sed -E -i "/name:\\s*APP_VERSION/{n;s#(\\s*value:\\s*)([\\\"\\']).*(\\2)#\\1\\2${newImageTag}\\2#;}" values.yaml"""
            sh(script: updateAppVersion)
            def dateCommand = timeZoneId != null ? 
                "TZ='${timeZoneId}' date '+%Y-%m-%dT%H:%M:%S'" : 
                "date '+%Y-%m-%dT%H:%M:%S'"
            def currentTime = sh(
                script: dateCommand,
                returnStdout: true
            ).trim()
            def updateBuildTime = """sed -E -i "/name:\\s*BUILD_TIME/{n;s#(\\s*value:\\s*)([\\\"\\']).*(\\2)#\\1\\2${currentTime}\\2#;}" values.yaml"""
            sh(script: updateBuildTime)
        }
    } catch (Exception e){
        e.printStackTrace()
    }
    return regexStr
}

def replaceImageTag(appName, serviceName, subPath, newImageTag, enableReplaceDebug = true, timeZoneId) {
    def regexStr = getReplaceTagRegex(appName, serviceName)
    try {
        dir(subPath) {
            def updateImageTag = "sed -E -i 's#${regexStr}#\\1${newImageTag}#g' values.yaml"
            sh(script: updateImageTag)
            def updateAppVersion = """sed -E -i "/name:\\s*APP_VERSION/{n;s#(\\s*value:\\s*)([\\\"\\']).*(\\2)#\\1\\2${newImageTag}\\2#;}" values.yaml"""
            sh(script: updateAppVersion)
            def dateCommand = timeZoneId != null ? 
                "TZ='${timeZoneId}' date '+%Y-%m-%dT%H:%M:%S'" : 
                "date '+%Y-%m-%dT%H:%M:%S'"
            def currentTime = sh(
                script: dateCommand,
                returnStdout: true
            ).trim()
            def updateBuildTime = """sed -E -i "/name:\\s*BUILD_TIME/{n;s#(\\s*value:\\s*)([\\\"\\']).*(\\2)#\\1\\2${currentTime}\\2#;}" values.yaml"""
            sh(script: updateBuildTime)
        }
    } catch (Exception e){
        e.printStackTrace()
    }
    return regexStr
}

def getReplaceTagRegex(appName, serviceName) {
    return '(^\\s*tag:\\s*)([a-zA-Z0-9_\\-]+)'
}

def getCredential() {
    return conf.credentials["argocd"]
}

def login(){
    (argocdDomain, argocdPort) = utils.getDomainAndPortFromUrl(this.argocdBaseUrl)
    def credential = getCredential()
    withCredentials([usernamePassword(credentialsId: credential, passwordVariable: 'ARGOCD_PASSWD', usernameVariable: 'ARGOCD_USR')]) {
        sh """
            set +x
            argocd login --grpc-web ${argocdDomain}:${argocdPort} \
              --username ${ARGOCD_USR} \
              --password '${ARGOCD_PASSWD}' \
              --insecure
        """
    }
}

def forceSyncApp(argocdAppName) {
    forceSync(argocdAppName)
}

def forceSync(argocdAppName){
    sh """
        argocd --grpc-web app sync ${argocdAppName} --force --prune
        argocd --grpc-web app wait ${argocdAppName} --timeout ${this.syncTimeout}
    """
}

def ARGOCD_APPNAME(targetEnv) {
    return "${this.appName}-${this.serviceName}-${targetEnv}"
}

def createApplication(String cdRepoUrl, String cdFilePath, String argocdAppName, String targetEnv) {
    def destNamespace = "${this.appName}-${this.deployEnv}"
    def destServer = "${this.cdServer}"
    def filePathToUpdate = cdFilePath ?: getSubPath(targetEnv, serviceName)
    sh """
        argocd --grpc-web app create ${argocdAppName} \
            --repo ${cdRepoUrl} \
            --revision ${this.cdRepoBranch} \
            --path ${filePathToUpdate} \
            --sync-option CreateNamespace=true \
            --dest-namespace ${destNamespace} \
            --dest-server ${destServer} \
            --project ${this.appName} \
            --revision-history-limit ${this.revision}
    """
    forceSyncApp(argocdAppName)
}

def checkApplicationExist(String argocdAppName){
    def appExists = sh(
        script: "argocd --grpc-web app get ${argocdAppName} >/dev/null 2>&1 && echo true || echo false",
        returnStdout: true
    ).trim().toBoolean()
    return appExists
}
