package repository.registry

import jenkins.Jenkins

class Harbor extends Jenkins{
    String domain
    String url
    String repositoryPrefix
    
    Harbor(def jenkins){
        this.jenkins = jenkins
        this.domain = jenkins.conf.repository.registry.domain
        this.url = "https://" + jenkins.conf.repository.registry.domain
    }

    String getRepositoryName(deployEnv, appName, serviceName) {
        execute {
            this.repositoryPrefix = jenkins.conf.repository.registry.repositoryPrefix[appName]
            return "${this.repositoryPrefix}/${deployEnv}/${appName}.${serviceName}"
        }
    }

    String getFullRepositoryName(deployEnv, appName, serviceName) {
        execute {
            String repoName = this.getRepositoryName(deployEnv, appName, serviceName)
            return "${this.domain}/${repoName}"
        }
    }

    def login(domain=this.domain) {
        execute {
            sh "echo '123qwe!@#4' | docker login ${domain} -u admin --password-stdin"
        }
    }
}