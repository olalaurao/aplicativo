allprojects {
    repositories {
        google()
        mavenCentral()
    }

    configurations.all {
        resolutionStrategy.eachDependency {
            if (requested.group == "androidx.glance" &&
                requested.name.startsWith("glance")
            ) {
                useVersion("1.1.1")
                because("home_widget 0.9.1 requests glance-appwidget:1.+, which currently resolves to 1.3.0-alpha01 and requires compileSdk 37/AGP 9.1.")
            }
        }
    }
}

val newBuildDir = rootProject.layout.projectDirectory.dir("../build").asFile
rootProject.layout.buildDirectory.set(newBuildDir)

subprojects {
    val newSubprojectBuildDir = newBuildDir.resolve(project.name)
    project.layout.buildDirectory.set(newSubprojectBuildDir)
    project.evaluationDependsOn(":app")

    if (name == "receive_sharing_intent") {
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            kotlinOptions.jvmTarget = "1.8"
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
