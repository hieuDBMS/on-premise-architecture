import groovy.transform.Field

@Field
def credentials = [
    "git-passwd": "gitlab-jenkins", // user and pat
    "git-ssh": "",
    "argocd": "argocd",
    "sonarqube": "sonarqube-token-cicd-analysis",
    "sonarqube-webhook": "sonarqube-webhook-analysis"
]

@Field
def repository = [
    registry: [
        domain: "registry.bbtech.io.vn",
        repositoryPrefix: [
            interpay: "nwf",
            ebank: "ebank"
        ]
    ],
    artifact: []
]

@Field
def notification = [
    email: "hieuminh.datas@gmail.com",
    lotusChat: [
        api_url: "bot.lotuschat.vn/bot12043600:O8GoJGQVtUSM0ovVBYUxW1ivKzhgnWugz73LfMDw/sendMessage",
        chat_id: ["51726868138156046", "16973779485312336"]
    ]
]

@Field
def gitConfig = [
    sshUrl: "git@gitlab.fis.vn",
    httpsUrl: "https://gitlab.fis.vn",
    domain: "gitlab.fis.vn",
    gitSsh: false,  // using HTTPs to push commit and tag to Git
    artifactTagRegex: /^(\d+)-(\w{7})$/,
    releaseTagRegex: /^v\d+\.\d+\.\d+$/
]

@Field
def gitlabConfig = [
    apiVersion: "v4",
    enableDebugHttpRequest: false,
]

// This config is using for remap user from Gitlab to Jenkins SSO user
@Field
def gitlabUserRemap = ["gitlab-jenkins": "gitlab-jenkins",]

@Field
def dockerTargetStages = [
    'pg': 'pg_stage',
    'ut': 'ut_stage',
    'artifact': 'artifact_stage',
    'image': 'final',
]

@Field
def envConfigMap = [
    dev: [
        branchRegex: '^develop(\\S*)$',
        branch: 'develop',
        argocd: [
            url: 'http://100.73.111.66:30080',
            syncTimeout: '600',
            server: 'https://100.111.246.52:6443',
            revision: '3'
        ]
    ],
    prod: [
        branchRegex: '^main(\\S*)$',
        branch: 'develop',
        argocd: [
            url: 'http://100.73.111.66:30080',
            syncTimeout: '600',
            server: 'https://100.111.246.52:6443',
            revision: '3'
        ]
    ],
]

@Field
def sonarConfig = [
    sonarQubeEnv: 'sonarqube',
    url: "https://sonarqube.bbtech.io.vn",
    qualityGateWay: "Jenkins way",
    scannerTimeout: 30, // Scanner timeout in minutes
    enableDebugHttpRequest: true,
    metricKeys: ['reliability_rating',
                    'security_rating',
                    'sqale_rating',
                    'coverage',
                    'security_hotspots'
                ]
]
