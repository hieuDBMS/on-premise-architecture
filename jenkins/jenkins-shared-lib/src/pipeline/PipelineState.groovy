package pipeline

enum PipelineState {
    SUCCESS('SUCCESS', 'Build Succeeded!', 'good'),
    FAILURE('FAILURE', 'Build failed! Please have a look!', 'attention'),
    UNSTABLE('UNSTABLE', 'Build Succeeded with Warning! Please have a look!', 'warning'),
    NOT_BUILT('NOT_BUILT', 'Not Build', 'light'),
    WAITING('WAITING', 'Waiting...', 'accent'),
    SONARQ_NOT_START('SONARQ_NOT_START', 'Jenkins did not trigger SonarQube analysis yet.', 'warning'),
    DEPENDENCY_CHECK_NOT_START('DEPENDENCY_CHECK_NOT_START', 'Jenkins did not trigger Dependency-check scan yet.', 'warning'),
    ARTIFACT_NOT_BUILD('ARTIFACT_NOT_BUILD', 'Jenkins did not build artifact successfully.', 'warning'),
    IMAGE_SCANNING_NOT_START('IMAGE_SCANNING_NOT_START', 'Container Image is not scanned yet.', 'warning'),

    final String state
    final String message
    final String color

    PipelineState(String state, String message, String color) {
        this.state = state
        this.message = message
        this.color = color
    }

    static PipelineState getByState(String state) {
        return values().find { it.state == state }
    }
}
