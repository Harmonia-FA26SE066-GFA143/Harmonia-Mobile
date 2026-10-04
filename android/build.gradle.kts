allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}
subprojects {
    val configureNdk: Project.() -> Unit = {
        extensions.findByName("android")?.let { ext ->
            try {
                ext.javaClass.getMethod("setNdkVersion", String::class.java).invoke(ext, "27.1.12297006")
            } catch (_: Exception) {
            }
        }
    }
    if (state.executed) {
        configureNdk()
    } else {
        afterEvaluate { configureNdk() }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
