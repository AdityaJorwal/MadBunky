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

    // Force glance-appwidget to a stable version compatible with compileSdk 36 / AGP 8.9.1.
    // home_widget 0.8.x pulls in glance-appwidget:1.3.0-alpha01 which requires compileSdk 37
    // and AGP 9.1.0+. Pinning to 1.1.0 (stable) avoids that requirement.
    configurations.all {
        resolutionStrategy {
            force("androidx.glance:glance-appwidget:1.1.0")
            force("androidx.glance:glance:1.1.0")
            force("androidx.glance:glance-material3:1.1.0")
            force("androidx.glance:glance-material:1.1.0")
        }
        // Exclude the alpha remote-creation-android dependency entirely —
        // it is pulled transitively by glance 1.3.0-alpha01 and is not needed.
        exclude(group = "androidx.compose.remote", module = "remote-creation-android")
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


