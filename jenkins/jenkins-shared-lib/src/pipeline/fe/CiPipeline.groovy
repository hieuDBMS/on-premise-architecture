#!/usr/bin/groovy
package pipeline.fe

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
            stage("Clean Workspace") {
                sh "rm -rf dist"
            }
            stage("Checkout FE Source") {
                this.pGit.init()
                this.tag = pGit.checkoutBranch(gitUrl, ciRepoBranch)
            }
            // stage ("Build Angular") {
            //     sh "npm install --force"
            //     sh "node --max_old_space_size=8192 ./node_modules/@angular/cli/bin/ng build --configuration=prod --output-path=dist"
            // }
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

