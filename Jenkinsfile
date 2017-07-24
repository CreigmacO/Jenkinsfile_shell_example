pipeline {
  agent any

    options {
        buildDiscarder(logRotator(numToKeepStr: '3'))
        ansiColor('xterm')
      }
    tools {
        maven 'M3'
        }
    environment {
         BUILD_ID = "${BUILD_NUMBER}"
         //VERSION = readMavenPom().getVersion()
         OPTUM_DTR = credentials('OptumDTR')
         OPTUM_OSE = credentials('OptumDTR')
    }
    parameters {
       choice(
               choices: 'Stage\nProd',
               description: '',
               name: 'REQUESTED_ACTION')
               booleanParam(defaultValue: false, description: 'Execute deploy', name: 'shouldDeploy')
               booleanParam(defaultValue: true, description: 'Execute Build', name: 'shouldBuild')
   }

  stages {
    stage ('Initialize') {
          steps {
                parallel(
                 environment:{
                             echo "Running ${env.BUILD_ID} on ${env.JENKINS_URL}"
                              script{

                                    //  def pom = readMavenPom file: 'pom.xml'
                                    //  echo sh(script: 'env', returnStdout: true)
                                      sh 'chmod 777 build/*.sh'
                                 }
                           },
                   verifyMaven:{
                             sh '''
                                 echo "PATH = ${PATH}"
                                 echo "M2_HOME = ${M2_HOME}"

                             '''
                           }
                         )
                    }
              }

  stage ('ShouldBuild'){

                steps{
                        script{
                                 result = sh (script: "git log --oneline -1 | grep 'stage'", returnStatus: true)

                                  echo "${env.shouldDeploy}"

                                      if (result == 0){
                                            echo ("This is not a new build")
                                            env.shouldBuild = "false"
                                            env.shouldDeploy = "true"
                                            echo "shouldBuild  IS NOW   ${env.shouldBuild}"
                                            echo "shouldDeploy IS NOW   ${env.shouldDeploy}"
                                      }



                      }
                  }
                }

    stage ('Build') {
                  when {
                       expression {env.shouldDeploy == "false" && env.shouldBuild == "true"  && currentBuild.result == null || currentBuild.result == 'SUCCESS'}
                       }
                      steps {

                            sh 'build/build-war.sh'
                          }
                      }

    stage('Build Docker Image') {
                   when {
                        expression {env.shouldDeploy == "false" && env.shouldBuild == "true"  && currentBuild.result == null || currentBuild.result == 'SUCCESS'}
                        }
                       steps{
                           script{
                                 sh '''
                                  export PATH=$PATH:/tools/docker/docker-1.11.2/ && build/build-docker.sh
                                   '''
                                   }
                             }
                       }

    stage('Deploy Docker Image'){
                      when {
                           expression { env.shouldDeploy == "false" &&
                                        env.shouldBuild == "true" &&
                                        currentBuild.result == null || currentBuild.result == 'SUCCESS'}
                           }
                        steps {
                          script {
                                  sh '''
                                     PATH=$PATH:/tools/docker/docker-1.11.2/ && build/push-dtr.sh
                                     '''
                                    }
                                }
                          }

    stage ('Deploy to Dev') {
                          when {
                               expression {env.shouldDeploy == "false" && env.shouldBuild == "true" }
                               }
                            steps {
                                script {
                                          sh 'build/deploy-dev.sh'
                                        }
                                  }
                          }

    stage ('Deployment input') {
                         when {
                                expression {env.shouldDeploy == "false" && env.shouldBuild == "true" }
                                }
                             steps{
                                 script{
                                     try {
                                           mail body: "Deployment to the ${env.REQUESTED_ACTION} has is provided here ${env.RUN_DISPLAY_URL}",
                                           to: "myron_smith@optum.com",
                                           from: "myron_smith@optum.com",
                                           subject:"Deployment Request to Test!"
                                           env.REQUESTED_ACTION = input message: 'DEPLOY TO TEST', ok: 'Deploy',
                                           parameters: [choice(name: 'REQUESTED_ACTION', choice: 'TsT', description: 'Do you want to Deploy?')]
                                           } catch (err) {
                                             mail body: "Deployment to ${env.BUILD_URL} for environment ${env.REQUESTED_ACTION} has been Aborted. ",
                                             to: "myron_smith@optum.com",
                                             from: "myron_smith@optum.com",
                                             subject:"Deployment to Test has been Aborted!"
                                             }
                                          }
                                         }
                                       }

    stage ('Deploy to Test') {
            when {
                   expression {params.REQUESTED_ACTION == 'TsT'  && currentBuild.result == null || currentBuild.result == 'SUCCESS' }
                 }
                steps {
                  script{
                        sh 'build/deploy-test.sh'
                        }
                  }
            }
   stage('Smoke Test TestEnv') {
            when {
                 expression {params.REQUESTED_ACTION == 'TsT' && env.shouldBuild == "true" }
                 }
                steps {
                    script{
                        sh 'build/smoke-test.sh'
                          }
                    }
              }


      stage ('Execute Stage Deployment') {
            when {
                 expression {env.shouldDeploy == "true" && params.REQUESTED_ACTION == "Stage"}
                  }
                steps {
                  timeout(time: 3, unit: 'DAYS'){
                      script{
                            try{

                              mail body: "Deployment to ${env.REQUESTED_ACTION} Please click ${env.RUN_DISPLAY_URL} to approve ",
                              to: "myron_smith@optum.com",
                              from: "myron_smith@optum.com",
                              subject:"Deployment to Stage Request!"
                              env.REQUESTED_ACTION = input message: 'DEPLOY TO TEST', ok: 'Deploy',
                              parameters: [choice(name: 'REQUESTED_ACTION', choices: 'Stage\nProd', description: 'Do you want to Deploy Stage?')]
                            }catch (err) {
                                         env.shouldDeploy = 'false'
                                         mail body: "Deployment to ${env.BUILD_URL} for environment ${env.REQUESTED_ACTION} has failed. ",
                                         to: "myron_smith@optum.com",
                                         from: "myron_smith@optum.com",
                                         subject:"Deployment has been Aborted!"
                                    }
                                    sh 'build/deploy-stage.sh'
                              }
                            }
                          }
                       }


      stage ('Execute Prod Deployment') {
          when {
               expression {result = sh (script: "git log -all --grep='Prod", returnStatus: true) && env.shouldDeploy == "true"}
                }
                steps {
                  timeout(time: 3, unit: 'DAYS'){
                    script{

                      try{
                        mail body: "Deployment to ${env.REQUESTED_ACTION} Please click ${env.RUN_DISPLAY_URL} to approve ",
                        to: "myron_smith@optum.com",
                        from: "myron_smith@optum.com",
                        subject:"Deployment to Production Request!"
                        env.REQUESTED_ACTION = input message: 'DEPLOY TO TEST', ok: 'Deploy',
                        parameters: [choice(name: 'REQUESTED_ACTION', choices: 'Prod', description: 'Do you want to Deploy to Production?')]
                      }catch (err) {
                                   env.shouldDeploy = 'false'
                                   mail body: "Deployment to ${env.BUILD_URL} for environment ${env.REQUESTED_ACTION} has failed ${env.shouldDeploy} is set to false. ",
                                   to: "myron_smith@optum.com",
                                   from: "myron_smith@optum.com",
                                   subject:"Deployment has been Aborted!"
                              }
                          }
                        }
                    }
                  }

                // The is the end of the stages

}
        // This is a post email. only runs after all jobs have finished.
        post {
                failure {
                        emailext(subject: "FAILURE: ${currentBuild.fullDisplayName}",
                              body: "${env.REQUESTED_ACTION} from branch ${BRANCH_NAME} - ${RUN_CHANGES_DISPLAY_URL} ",
                              attachLog: true,
                              replyTo: 'me@me.com',
                              to: 'myron_smith@optum.com') }

                            }





}
