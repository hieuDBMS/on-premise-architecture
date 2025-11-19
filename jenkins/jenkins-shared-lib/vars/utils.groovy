def getCredentials(key=null){
    if(key){
        try{
            return conf.credentials.get(key)
        } catch(e){
            error e.getMessage()
        }
    }
    return conf.credentials
}

def getStarter(allowFailure=true){
    def starter
    try{
        starter = currentBuild.getRawBuild().getCause(Cause.UserIdCause).getUserId()
    } catch (e) {
        starter = getActorEmail(env.actor, allowFailure)
    }
    return starter
}

def getActorEmail(actor, allowFailure=true){
    def actorEmail
    try{
        // Try to remap user if needed
        actor = conf.gitlabUserRemap.get(actor, '') ?: actor
        // Try to get from Generic Webhook Trigger
        assumeEmail = "${actor}@${conf.domain}"
        actorEmail = getEmailFromUserId(assumeEmail)
    } catch(ex){
    }
    return actorEmail
}

def getStarterEmail(getEmail=true){
	def starter
	try{
		String buildUserId = currentBuild.getRawBuild().getCause(Cause.UserIdCause).getUserId()
		starter = getEmail ? getEmailFromUserId(buildUserId) : buildUserId
	} catch(e){
		try{
		    // Try to remap user if needed
		    env.actor = conf.gitlabUserRemap.get(env.actor, '') ?: env.actor
			// Try to get from Generic Webhook Trigger
			starter = getEmail ? getEmailFromUserId(env.actor) : env.actor
		} catch(ex){
			error "Error during get Build User. ${getStackTrace(ex)}"
		}
	}
    return starter
}

def getEmailFromUserId(userId){
	def email
	try{
		hudson.model.User userObj = hudson.model.User.getById(userId, false)
		email = userObj?.getProperty(hudson.tasks.Mailer.UserProperty.class).getAddress()
	} catch(e){
		getStackTrace(e)
		error("Cannot get email address from user ${userId}")
	}
	return email
}

def getUserFromEmail(email){
	def userId
	try{
		userId = email.split("@")[0]
	} catch(e){
		getStackTrace(e)
		error("Cannot get user ID from email ${email}")
	}
	return userId
}

def cleaning(){
    cleanWs(
        disableDeferredWipeout: true,
        deleteDirs: true
    )
}

def getBuildTime(timeFormat="%Y%m%d%H%M%S"){
    return sh(returnStdout: true, script: "date +${timeFormat}").trim()
    //return currentBuild.getRawBuild().getTime().format(timeFormat)
}

def getBuildTimeJ(timeFormat="yyyyMMddHHmmSS"){
    date = new Date()
    dateFormat = new java.text.SimpleDateFormat(timeFormat)
    return dateFormat.format(date)
}

def setBuildState(state) {
    currentBuild.getRawBuild().getExecutor().interrupt(state)
    sleep(2)   // Interrupt is not blocking and does not take effect immediately.
}

def getLastSuccessfulBuild(jobFullName=JOB_BASE_NAME){
    try{
        return Jenkins.getInstance().getItemByFullName(jobFullName).lastSuccessfulBuild.number
    } catch(NullPointerException) {
        return 0
    }
}

def getCurrentBuildNumber(){
    return currentBuild.number
}

def yamlParser(yamlString){
    if(yamlString?.trim()){
        yamlObj = readYaml(text: yamlString)
        if(yamlObj == []) {
            return [:]
        }
        return yamlObj
    }
    return [:]
}

def yamlToText(yamlObj){
	currentTime = getBuildTimeJ()
	tmpFileName = "${currentTime}-tmpYamlData.yml"
    writeYaml(file: tmpFileName, data: yamlObj)
    dataTxt = readFile(tmpFileName)
    //delete file
    //sh "rm -rf tmpYamlData.yml"
    return dataTxt
}


def updateBuildDescription(descMap, extraDesc=''){
    if(!descMap){
        return
    }
    descString = yamlToText(descMap)
    if(extraDesc){
        currentBuild.description = "${extraDesc}\n${descString}"
    } else {
        currentBuild.description = descString
    }
}

def updatePipelineDescription(descMap){
    descMap = deepPruneMap(descMap)
    if(!descMap){
        return
    }
    desc = yamlToText(descMap)
    currentBuild.rawBuild.project.description = desc
}

def deepPruneMap(Map map) {
    return map.collectEntries { k, v ->
        [k, v instanceof Map ? deepPruneMap(v) : v]
    }.findAll { k, v -> v != [:] && v != [] && v != null && v != ''}
}

def regexMatcher(content, regex){
	return (content =~ regex) ? true : false
}

def String getStackTrace(Throwable aThrowable){
    ByteArrayOutputStream baos = new ByteArrayOutputStream();
    PrintStream ps = new PrintStream(baos, true);
    aThrowable.printStackTrace(ps);
    return baos.toString();
}


def getTriggerRegex(deployEnv, gitUrl=''){
	// Check the url is end with .git or not
	if(!gitUrl.endsWith(".git")){
		gitUrl += ".git"
	}
	gitUrlRegex = gitUrl.replaceAll("\\/", "\\\\/")
	
	if(deployEnv == 'dev'){
		return '^((develop(.*))\\s){1}(' + gitUrlRegex + ')(\\s{1}merged)$'
	}
	if(deployEnv == 'uat'){
		return '^(((release|hotfix)/(.*))\\s){1}(' + gitUrlRegex + ')\\s$'
	}
	//if(deployEnv == 'prod'){
	//	return '^((main)\\s){1}(' + gitUrlRegex + ')$'
	//}
}

def convertFromMapToString(infoMap){
    infoMap = deepPruneMap(infoMap)
    if(!infoMap){
        return ''
    }
    return yamlToText(infoMap)
}

def getPodTemplate(String fileName) {
    return libraryResource("podTemplate/${fileName}")
}

def awsCmd(cmd, allowFailure=false, enableDebug=false, region=conf.awsRegion){
    debugCmd = enableDebug ?  "" : "set +x;"  // Display running comamnds for debugging

    def response = ''
    try {
        output = sh(returnStdout: true, script: "${debugCmd} ${cmd} --region ${region} --output json").trim()
        response = readJSON(text: output)
    } catch (Exception e) {
        // Handle the exception if the command fails
        if(allowFailure){
            echo "Error: ${e.getMessage()}"
        } else {
            error "Error: ${e.getMessage()}"
        }
    } finally {
        return response
    }
}

def checkException(errorMessage, exceptionName){
    return errorMessage.matches(".*\\(${exceptionName}\\).*")
}

def getDomainAndPortFromUrl(String urlString) {
    // Create a URL object from the string
    def url = new URL(urlString)

    // Get the domain (host) from the URL
    def domain = url.getHost()

    // Get the port from the URL; returns -1 if the port is not explicitly specified
    def port = url.getPort()
    port = port == -1 ? url.getDefaultPort() : port // Use default port if no port is specified

    return [domain, port]
}

String convertCamelCase(String str) {
// Replace each lowercase letter followed by an uppercase letter with
// the same letters separated by a space and capitalize the first letter
    return str.replaceAll(/(?<=[a-z])(?=[A-Z])/, ' ').capitalize()
}

def isUrl(String str) {
    // Regex pattern for URL validation
    String urlPattern = '^(http[s]?:\\/\\/)([\\w-]+\\.)+[\\w-]+(?::(\\d+))?(\\/[\\w\\- .\\/:@?%&=]*)?$'
    // Compile the regex pattern
    return regexMatcher(str, urlPattern)
}

def isEmail(String str) {
    // Regex pattern for URL validation
    String pattern = '((?!\\.)[\\w\\-_.]*[^.])(@\\w+\\.\\w+(\\.\\w+)?[^.\\W])'
    // Compile the regex pattern
    return regexMatcher(str, pattern)
}

def checkObjectType(obj) {
    // Get the class of the object
    Class objClass = obj.getClass()
    // Return the simple name of the class
    return objClass.simpleName
}

def isArrayList(Object obj) {
    return obj instanceof ArrayList
}

def checkDockerDaemon(maxRetries = 20, debug=false) {
    def retryInterval = 3
    def retryCount = 0
    def debugCmd = debug ? '' : "> /dev/null 2>&1"
    while (retryCount < maxRetries) {
        try {
            sh "set +x; docker ps  ${debugCmd}"
            println('Docker daemon is running.')
            return true
        } catch (e) {
            retryCount++
            println("Attempt ${retryCount}/${maxRetries}: Docker daemon is not running, retrying in ${retryInterval} seconds...")
            sleep(retryInterval)
        }
    }
    println('Reached maximum retry attempts. Docker daemon is not running.')
    return false
}

def yamlToProperties(yamlFile, propertiesFile) {
    def data = readYaml file: yamlFile
    def props = new StringBuilder()

    // Flatten YAML (recursive helper)
    def flattenMap
    flattenMap = { prefix, map ->
        map.each { key, value ->
        def fullKey = prefix ? "${prefix}.${key}" : key
        if (value instanceof Map) {
            flattenMap(fullKey, value)
        } else {
            props.append("${fullKey}=${value}\n")
        }
        }
    }

    flattenMap("", data)
    writeFile(file: propertiesFile, text: props.toString())
}

