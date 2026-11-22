plugins {
    kotlin("jvm") version "2.2.20"
}

group = "com.johntsui.stroom"
version = "1.0"

kotlin {
    jvmToolchain(17)
}

dependencies {
    testImplementation("junit:junit:4.13.2")
}
