#!/usr/bin/groovy
package pipeline.be

import jenkins.Jenkins
import deploy.argocd.*

class CdPipeline extends Jenkins {
    def argocd

    CdPipeline(def jenkins){
        this.jenkins = jenkins
        this.argocd = new Argocd()
    }

    def commonStages(String deployEnv, String appName, String serviceName, String imageTag, String cdRepoUrl) {
        execute {
            stage("Update Argo Tag") {
                this.argocd.init(deployEnv, appName, serviceName)
                this.argocd.deploy(imageTag, deployEnv, cdRepoUrl)
            }
        }
    }
}

