ThisBuild / scalaVersion := "2.13.13"
ThisBuild / version := "0.1.0-SNAPSHOT"
ThisBuild / organization := "org.ghutchis"

val chiselVersion = "6.7.0"

lazy val root = (project in file("."))
  .settings(
    name := "TV80",
    libraryDependencies ++= Seq(
      "org.chipsalliance" %% "chisel" % chiselVersion
      ),

    scalacOptions ++= Seq(
      "-language:reflectiveCalls",
      "-deprecation",
      "-feature",
      "-Xcheckinit",
      "-Ymacro-annotations"
    ),
    addCompilerPlugin("org.chipsalliance" % "chisel-plugin" % chiselVersion cross CrossVersion.full),
  )

