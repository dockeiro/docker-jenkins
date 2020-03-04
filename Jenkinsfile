pipeline {
  agent {
    label 'X86-64-MULTI'
  }
  // Configuration for the variables used for this specific repo
  environment {
    BUILDS_DISCORD=credentials('build_webhook_url')
    GITHUB_TOKEN=credentials('498b4638-2d04-4ce5-832d-8a57d01d97ac')
    EXT_USER = 'jenkinsci'
    EXT_REPO = 'jenkins'
    MY_BRANCH = 'slim'
    EXT_VERSION = 'lts'
    MY_USER = 'gustavo8000br'
    MY_REPO = 'docker-jenkins'
    DOCKERHUB_IMAGE = 'gustavo8000br/docker-jenkins'
    MULTIARCH='true'
  }
  stages {
    // Setup all the basic environment variables needed for the build
    stage("Set ENV Variables base"){
      steps{
        script{
          env.EXIT_STATUS = ''
          env.GITHUB_DATE = sh(
            script: '''date '+%Y-%m-%dT%H:%M:%S%:z' ''',
            returnStdout: true).trim()
          env.COMMIT_SHA = sh(
            script: '''git rev-parse HEAD''',
            returnStdout: true).trim()
          env.CODE_URL = 'https://github.com/' + env.MY_USER + '/' + env.MY_REPO + '/commit/' + env.GIT_COMMIT
          env.DOCKERHUB_LINK = 'https://hub.docker.com/r/' + env.DOCKERHUB_IMAGE + '/tags/'
        }
      }
    }
    /* ########################
       External Release Tagging
       ######################## */
    // If this is a stable github release use the latest endpoint from github to determine the ext tag
    stage("Set ENV github_stable"){
     steps{
       script{
         env.EXT_RELEASE = sh(
           script: '''curl -s https://api.github.com/repos/${EXT_USER}/${EXT_REPO}/releases | jq '.[0] .name' | sed 's/[~,%@+;:/"]//g' ''',
           returnStdout: true).trim()
       }
       script{
         env.TINI_VERSION = sh(
           script: '''curl -s https://api.github.com/repos/krallin/tini/releases | jq '.[0] .name' | sed 's/[~,%@+;:/"]//g' ''',
           returnStdout: true).trim()
       }
     }
    }
    // If this is a stable or devel github release generate the link for the build message
    stage("Set ENV github_link"){
     steps{
       script{
         env.RELEASE_LINK = 'https://github.com/' + env.EXT_USER + '/' + env.EXT_REPO + '/releases/tag/' + env.EXT_RELEASE
       }
     }
    }
    // If this is a '${MY_BRANCH}' build use live docker endpoints
    stage("Set ENV live build"){
      when {
        branch env.MY_BRANCH
        environment name: 'CHANGE_ID', value: ''
      }
      steps {
        script{
          env.IMAGE = env.DOCKERHUB_IMAGE
          env.META_TAG = env.EXT_RELEASE
        }
      }
    }
    /* ###############
       Build Container
       ############### */
    // Build Docker container for push to LS Repo
    stage('Build-Single') {
      when {
        environment name: 'MULTIARCH', value: 'false'
        environment name: 'EXIT_STATUS', value: ''
      }
      steps {
        sh "docker buildx build --platform=linux/amd64 --no-cache --pull -t ${IMAGE}:${MY_BRANCH}-${EXT_VERSION}-${META_TAG} \
        --build-arg TINI_VERSION=${TINI_VERSION} --build-arg VERSION=${META_TAG} --build-arg BUILD_DATE=${GITHUB_DATE} --push ."
      }
    }
    // Build MultiArch Docker containers for push to LS Repo
    stage('Build-Multi') {
      when {
        environment name: 'MULTIARCH', value: 'true'
        environment name: 'EXIT_STATUS', value: ''
      }
      parallel {
        stage('Build X86') {
          steps {
            sh "docker buildx build --platform=linux/amd64 --no-cache --pull -t ${IMAGE}:amd64-${MY_BRANCH}-${EXT_VERSION}-${META_TAG} \
            --build-arg TINI_VERSION=${TINI_VERSION} --build-arg VERSION=${META_TAG} --build-arg BUILD_DATE=${GITHUB_DATE} --push ."
          }
        }
        stage('Build ARM64') {
          agent {
            label 'ARM64'
          }
          steps {
            withCredentials([
              [
                $class: 'UsernamePasswordMultiBinding',
                credentialsId: '3f9ba4d5-100d-45b0-a3c4-633fd6061207',
                usernameVariable: 'DOCKERUSER',
                passwordVariable: 'DOCKERPASS'
              ]
            ]) {
              echo 'Logging into DockerHub'
              sh '''#! /bin/bash
                 echo $DOCKERPASS | docker login -u $DOCKERUSER --password-stdin
                 '''
              sh "docker buildx build --platform=linux/arm64 --no-cache --pull -f Dockerfile.aarch64 -t ${IMAGE}:arm64v8-${MY_BRANCH}-${EXT_VERSION}-${META_TAG} \
                        --build-arg TINI_VERSION=${TINI_VERSION} --build-arg VERSION=${META_TAG} --build-arg BUILD_DATE=${GITHUB_DATE} --push ."
            }
          }
        }
      }
    }
    /* ##################
         Release Logic
       ################## */
    // If this is an amd64 only image only push a single image
    stage('Docker-Push-Single') {
      when {
        environment name: 'MULTIARCH', value: 'false'
        environment name: 'EXIT_STATUS', value: ''
      }
      steps {
        withCredentials([
          [
            $class: 'UsernamePasswordMultiBinding',
            credentialsId: '3f9ba4d5-100d-45b0-a3c4-633fd6061207',
            usernameVariable: 'DOCKERUSER',
            passwordVariable: 'DOCKERPASS'
          ]
        ]) {
          echo 'Logging into DockerHub'
          sh '''#! /bin/bash
             echo $DOCKERPASS | docker login -u $DOCKERUSER --password-stdin
             '''
          sh "docker tag ${IMAGE}:${MY_BRANCH}-${EXT_VERSION}-${META_TAG} ${IMAGE}:${MY_BRANCH}-${EXT_VERSION}-latest"
          sh "docker push ${IMAGE}:${MY_BRANCH}-${EXT_VERSION}-latest"
          sh "docker push ${IMAGE}:${MY_BRANCH}-${EXT_VERSION}-${META_TAG}"
          sh '''docker rmi \
                ${IMAGE}:${MY_BRANCH}-${EXT_VERSION}-${META_TAG} \
                ${IMAGE}:${MY_BRANCH}-${EXT_VERSION}-latest || :'''

        }
      }
    }
    // If this is a multi arch release push all images and define the manifest
    stage('Docker-Push-Multi') {
      when {
        environment name: 'MULTIARCH', value: 'true'
        environment name: 'EXIT_STATUS', value: ''
      }
      steps {
        withCredentials([
          [
            $class: 'UsernamePasswordMultiBinding',
            credentialsId: '3f9ba4d5-100d-45b0-a3c4-633fd6061207',
            usernameVariable: 'DOCKERUSER',
            passwordVariable: 'DOCKERPASS'
          ]
        ]) {
          sh '''#! /bin/bash
             echo $DOCKERPASS | docker login -u $DOCKERUSER --password-stdin
             '''
          sh "docker tag ${IMAGE}:amd64-${MY_BRANCH}-${EXT_VERSION}-${META_TAG} ${IMAGE}:amd64-${MY_BRANCH}-${EXT_VERSION}-latest"
          sh "docker tag ${IMAGE}:arm64v8-${MY_BRANCH}-${EXT_VERSION}-${META_TAG} ${IMAGE}:arm64v8-${MY_BRANCH}-${EXT_VERSION}-latest"
          sh "docker push ${IMAGE}:amd64-${MY_BRANCH}-${EXT_VERSION}-latest"
          sh "docker push ${IMAGE}:arm64v8-${MY_BRANCH}-${EXT_VERSION}-latest"
          sh "docker manifest push --purge ${IMAGE}:${MY_BRANCH}-${EXT_VERSION}-latest || :"
          sh "docker manifest create ${IMAGE}:${MY_BRANCH}-${EXT_VERSION}-latest ${IMAGE}:amd64-${MY_BRANCH}-${EXT_VERSION}-latest ${IMAGE}:arm64v8-${MY_BRANCH}-${EXT_VERSION}-latest"
          sh "docker manifest annotate ${IMAGE}:${MY_BRANCH}-${EXT_VERSION}-latest ${IMAGE}:arm64v8-${MY_BRANCH}-${EXT_VERSION}-latest --os linux --arch arm64 --variant v8"
          sh "docker manifest push --purge ${IMAGE}:${MY_BRANCH}-${EXT_VERSION}-${META_TAG} || :"
          sh "docker manifest create ${IMAGE}:${MY_BRANCH}-${EXT_VERSION}-${META_TAG} ${IMAGE}:amd64-${MY_BRANCH}-${EXT_VERSION}-${META_TAG} ${IMAGE}:arm64v8-${MY_BRANCH}-${EXT_VERSION}-${META_TAG}"
          sh "docker manifest annotate ${IMAGE}:${MY_BRANCH}-${EXT_VERSION}-${META_TAG} ${IMAGE}:arm64v8-${MY_BRANCH}-${EXT_VERSION}-${META_TAG} --os linux --arch arm64 --variant v8"
          sh "docker manifest push --purge ${IMAGE}:${MY_BRANCH}-${EXT_VERSION}-latest"
          sh "docker manifest push --purge ${IMAGE}:${MY_BRANCH}-${EXT_VERSION}-${META_TAG}"
          sh '''docker rmi \
                ${IMAGE}:amd64-${MY_BRANCH}-${EXT_VERSION}-${META_TAG} \
                ${IMAGE}:amd64-${MY_BRANCH}-${EXT_VERSION}-latest \
                ${IMAGE}:arm64v8-${MY_BRANCH}-${EXT_VERSION}-${META_TAG} \
                ${IMAGE}:arm64v8-${MY_BRANCH}-${EXT_VERSION}-latest || :'''
        }
      }
    }
  /* ######################
     Send status to Discord
     ###################### */
  post {
    always {
      script{
          if (env.EXIT_STATUS == "ABORTED"){
            sh 'echo "build aborted"'
          }
          else if (currentBuild.currentResult == "SUCCESS"){
            sh ''' curl -X POST -H "Content-Type: application/json" --data '{"avatar_url": "https://s3-sa-east-1.amazonaws.com/overstack.codes/cicd-jenkins-assets/ninjenkins2.png","embeds": [{"color": 1681177,\
                    "description": "**Build:**  '${BUILD_NUMBER}'\\n**Status:**  Success\\n**Job:** '${RUN_DISPLAY_URL}'\\n**Change:** '${CODE_URL}'\\n**External Release:**: '${RELEASE_LINK}'\\n**DockerHub:** '${DOCKERHUB_LINK}'\\n"}],\
                    "username": "Jenkins"}' ${BUILDS_DISCORD} '''
          }
          else {
            sh ''' curl -X POST -H "Content-Type: application/json" --data '{"avatar_url": "https://s3-sa-east-1.amazonaws.com/overstack.codes/cicd-jenkins-assets/fire-jenkins.png","embeds": [{"color": 16711680,\
                    "description": "**Build:**  '${BUILD_NUMBER}'\\n**Status:**  failure\\n**Job:** '${RUN_DISPLAY_URL}'\\n**Change:** '${CODE_URL}'\\n**External Release:**: '${RELEASE_LINK}'\\n**DockerHub:** '${DOCKERHUB_LINK}'\\n"}],\
                    "username": "Jenkins"}' ${BUILDS_DISCORD} '''
          }
        }
      // End script Send status to Discord
    }
  }
}
