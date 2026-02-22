plugins {
    id("com.google.gms.google-services") version "4.4.4" apply false
}

import com.android.build.gradle.BaseExtension

allprojects {
    repositories {
        google()
        maven { url = uri("https://repo1.maven.org/maven2") }
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

    if (project.name == "quick_settings") {
        pluginManager.withPlugin("com.android.library") {
            extensions.configure<com.android.build.gradle.LibraryExtension> {
                namespace = "io.apparence.quick_settings"
            }
        }
    }

    afterEvaluate {

        project.tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            kotlinOptions {
                jvmTarget = "17"
            }
        }
        
        project.extensions.findByType(BaseExtension::class.java)?.apply {
            compileSdkVersion(36)
            compileOptions {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}


