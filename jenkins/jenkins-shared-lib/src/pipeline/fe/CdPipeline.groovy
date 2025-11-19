#!/usr/bin/groovy
package pipeline.fe

import jenkins.Jenkins
import deploy.argocd.*

class CdPipeline extends Jenkins {
    def argocd

    CdPipeline(def jenkins){
        this.jenkins = jenkins
        this.argocd = new Argocd()
    }

    def commonStages(String deployEnv, String appName, String serviceName, String imageTag, String cdRepoUrl, String timeZoneId) {
        execute {
            stage("Update Argo Repo And Sync") {
                echo "${cdRepoUrl}"
                this.argocd.init(deployEnv, appName, serviceName)
                this.argocd.deploy(imageTag, deployEnv, cdRepoUrl, timeZoneId)
            }
        }
    }
}

