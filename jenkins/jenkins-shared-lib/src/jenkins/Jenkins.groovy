package jenkins

abstract class Jenkins {
    public def jenkins

    def execute(stage) {
        stage.delegate = this.jenkins
        stage()
    }
}
