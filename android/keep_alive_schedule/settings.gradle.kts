pluginManagement {
    repositories {
        // Use a Maven Central mirror before the portal's GitHub redirect for
        // Kotlin compiler artifacts, which can time out in GitHub Actions.
        maven { url = uri("https://maven-central.storage-download.googleapis.com/maven2/") }
        gradlePluginPortal()
        mavenCentral()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        maven { url = uri("https://maven-central.storage-download.googleapis.com/maven2/") }
        mavenCentral()
    }
}

rootProject.name = "keep-alive-schedule"
