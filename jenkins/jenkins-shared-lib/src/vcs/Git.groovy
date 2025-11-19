#!/usr/bin/groovy
package vcs

import vcs.Test
import pipeline.*


def domain
def httpsUrl
def sshUrl
def sshKeyCredentialId
def passwdCredentialId
def botUser

def init(){
    this.domain = conf.gitConfig.domain
    this.httpsUrl = conf.gitConfig.httpsUrl
    this.sshUrl = conf.gitConfig.sshUrl

    this.sshKeyCredentialId = conf.credentials['git-ssh']
    this.passwdCredentialId = conf.credentials['git-passwd']

    this.botUser = [
        email: "jenkins_bot@${conf.gitConfig.domain}",
        name : "Jenkins Bot"
    ]
}

def checkoutBranch(String gitUrl, String branch = "develop", 
                    Boolean genTag = true, Boolean gitSSH = false, String cloneDir = null)
{
    gitConfigUser()
    echo "Working on branch \"${branch}\""
    
    String gitCredential
    String sshUrlPath = this.sshUrl + ":"
    String httpsUrlPath = this.httpsUrl + "/"
    
    echo "${gitUrl}"
    echo "${sshUrlPath} And ${httpsUrlPath}"

    if (gitSSH) {
        // Clone with SSH
        println "Cline protocol: SSH"
        gitUrl = gitUrl.replaceAll(httpsUrlPath, sshUrlPath)
        gitCredential = this.sshKeyCredentialId
    } else {
        // Clone with HTTPS
        println "Clone protocol: HTTPS"
        gitUrl = gitUrl.replaceAll(sshUrlPath, httpsUrlPath)
        gitCredential = this.passwdCredentialId
    }

    if (cloneDir) {
        println "Git clone: $gitUrl into $cloneDir"
        dir(cloneDir) {
            git (
                url: gitUrl,
                credentialsId: gitCredential,
                branch: branch
            )
        }
    } else {
        println "Git clone: $gitUrl into default workspace"
        git (
            url: gitUrl,
            credentialsId: gitCredential,
            branch: branch
        )
    }

    if (genTag) {
        commitHash = getCommitHash(cloneDir)
        currentBuildId = utils.getCurrentBuildNumber()
        return getTag(commitHash, currentBuildId)
    }
    return
}

def push(gitUrl, target, gitSsh = false){
    if (gitSsh) {
        pushSsh(target)
    } else {
        pushHttps(gitUrl, target)
    }
}

def pushSsh(String target) {
    sshagent([this.sshKeyCredentialId]) {
        pushCmd = "git push origin ${target}"
        try {
            response = sh(returnStdout: true, script: pushCmd).trim()
        } catch (e) {
            env.BUILD_STATUS = PipelineState.UNSTABLE.state
            unstable("Unable to push to ${target} in Git")
        }
    }
}

def pushHttps(String gitUrl, String target) {
    withCredentials([gitUsernamePassword(credentialsId: this.passwdCredentialId, gitToolName: 'git-tool')])
    {
        sh """
            set +x
            git push origin ${target}
        """
    }
}

def gitConfigUser(userName = this.botUser.name, userEmail = this.botUser.email) {
    sh """
        set +x
        git config --global user.email '${userEmail}'
        git config --global user.name '${userName}'
    """
}

def getCommitHash(String cloneDir = null){
    if (cloneDir) {
        dir(cloneDir) {
            return sh(returnStdout: true, script: "git log -n 1 --pretty=format:'%h'").trim()
        }
    } else {
        return sh(returnStdout: true, script: "git log -n 1 --pretty=format:'%h'").trim()
    }
}

def getTag(commitHash, buildNumber){
    return "${buildNumber}-${commitHash}"
}

def commit(path, message) {
    gitConfigUser()
    sh """
        git add ${path}
        git commit -m '${message}'
    """
}

    // def testFunct(String name){
    //     execute{
    //         Test test = new Test()
    //         test.init(name)
    //         test.testfunction(name)
    //     }
    // }


