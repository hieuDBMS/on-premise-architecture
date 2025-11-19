#!/usr/bin/groovy
package pipeline.be

import jenkins.Jenkins
import repository.registry.*
import vcs.*
import build.docker.*

class CiPipeline extends Jenkins {
    def builder
    def pGit
    def targetStage
    def tag

    CiPipeline(def jenkins){
        this.jenkins = jenkins
        this.pGit = new Git()
        this.builder = new Builder()
        this.targetStage = jenkins.conf.dockerTargetStages
    }

    def commonStages(String gitUrl, String deployEnv) {
        execute {
            def ciRepoBranch = jenkins.conf.envConfigMap[deployEnv]['branch']
            stage("Checkout Be Source") {
                this.pGit.init()
                this.tag = pGit.checkoutBranch(gitUrl, ciRepoBranch)
            }
            return this.tag
        }
    }

    def build(deployEnv, appName, serviceName) {
        execute {
            stage("Build Image") {
                this.builder.init()
                this.builder.build(deployEnv, appName, serviceName, this.tag)
            }
        }
    }
}

