#!/usr/bin/groovy
package build.docker

import repository.registry.*

def registry
def targetStage

def init(){
    this.registry = new Harbor(this)
    this.targetStage = conf.dockerTargetStages
}

def build(deployEnv, appName, serviceName, tag, extraBuildConfig = '', workspaceDir = '.', isPush = true) {
    utils.checkDockerDaemon()
    String fullRepoName = this.registry.getFullRepositoryName(deployEnv, appName, serviceName)
    // def buildTarget = this.targetStage['image']

    dir(workspaceDir) {
        registry.login(this.registry.domain)
        echo "Starting Building Image"
        sh "docker build -t ${fullRepoName}:${tag} ${extraBuildConfig} ."
        if(isPush) {
            sh "docker push ${fullRepoName}:${tag}"
        }
        echo "Cleaning up local images"
        sh "docker image rm -f \$(docker images -q ${fullRepoName}) || true"
        sh "docker image prune -f"
    }
    return [fullRepoName, tag]
}

