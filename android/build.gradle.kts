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
    if (project.name != "app") {
        afterEvaluate {
            extensions.findByType(com.android.build.gradle.BaseExtension::class.java)?.let { androidExt ->
                // NDK 27.1.12297006 is the verified, installed NDK on this workstation.
                // AGP 9.1.0 defaults to NDK 28.2 which fails to auto-download due to network timeouts.
                // Setting ndkVersion here ensures native subprojects (e.g. :jni) build successfully.
                androidExt.ndkVersion = "27.1.12297006"
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
