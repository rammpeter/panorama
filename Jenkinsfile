pipeline {
  agent any
  environment {
    JRUBY_OPTS = '-J-Xmx1024m'
  }
  stages {
    stage('Prepare') {
      steps {
        sh 'rm -f Gemfile.lock'
        sh 'rm -rf client_info.store'
        sh 'rm -f Usage.log'
        sh 'rvm list'
        sh 'bundle install'
        sh 'rm -f test/dummy/log/test.log'
      }
    }

    stage('Docker start 12.1') {
      steps {
         sh 'docker start oracle121'
         sleep 20
       }
    }
    stage('Test 12.1 diagnostics_and_tuning_pack') {
      environment {
        DB_VERSION = '12.1'
        MANAGEMENT_PACK_LICENSE = 'diagnostics_and_tuning_pack'
      }
      steps {
         // sh 'rake TESTOPTS="-v" test'
         sh 'rake test'
      }
    }
    stage('Test 12.1 without tuning pack') {
      environment {
        DB_VERSION = '12.1'
        MANAGEMENT_PACK_LICENSE = 'diagnostics_pack'
      }
      steps {
         // sh 'rake TESTOPTS="-v" test'
         sh 'rake test'
      }
    }
    stage('Test 12.1 without diagnostics and tuning pack') {
      environment {
        DB_VERSION = '12.1'
        MANAGEMENT_PACK_LICENSE = 'none'
      }
      steps {
         // sh 'rake TESTOPTS="-v" test'
         sh 'rake test'
      }
    }
    stage('Docker stop 12.1') {
      steps {
         sh '#docker stop oracle121'
         sleep 20
       }
    }

    stage('Docker start 11.2') {
      steps {
         sh 'docker start oracle112'
         sleep 20
       }
    }
    stage('Test 11.2 diagnostics_and_tuning_pack') {
      environment {
        DB_VERSION = '11.2'
        MANAGEMENT_PACK_LICENSE = 'diagnostics_and_tuning_pack'
      }
      steps {
         // sh 'rake TESTOPTS="-v" test'
         sh 'rake test'
      }
    }
    stage('Test 11.2 without tuning pack') {
      environment {
        DB_VERSION = '11.2'
        MANAGEMENT_PACK_LICENSE = 'diagnostics_pack'
      }
      steps {
         // sh 'rake TESTOPTS="-v" test'
         sh 'rake test'
      }
    }
    stage('Test 11.2 without diagnostics and tuning pack') {
      environment {
        DB_VERSION = '11.2'
        MANAGEMENT_PACK_LICENSE = 'none'
      }
      steps {
         // sh 'rake TESTOPTS="-v" test'
         sh 'rake test'
      }
    }
    stage('Docker stop 11.2') {
      steps {
         sh '#docker stop oracle112'
         sleep 20
       }
    }

    stage('Docker start 12.1 SE') {
      steps {
         sh 'docker start oracle121se'
         sleep 20
       }
    }
    stage('Test 12.1 SE without diagnostics and tuning pack') {
      environment {
        DB_VERSION = '12.1_SE'
        MANAGEMENT_PACK_LICENSE = 'none'
      }
      steps {
         // sh 'rake TESTOPTS="-v" test'
         sh 'rake test'
      }
    }
    stage('Test 12.1 SE with Panorama-Sampler') {
      environment {
        DB_VERSION = '12.1_SE'
        MANAGEMENT_PACK_LICENSE = 'panorama_sampler'
      }
      steps {
         sh 'rake test'
      }
    }
    stage('Docker stop 12.1 SE') {
      steps {
         sh 'docker stop oracle121se'
         sleep 20
       }
    }

    stage('Docker start 12.2 EE') {
      steps {
         sh 'docker start oracle_12.2.0.1-ee'
         sleep 20
       }
    }
    stage('Test 12.2 PDB diagnostics_and_tuning_pack') {
      environment {
        DB_VERSION = '12.2_PDB'
        MANAGEMENT_PACK_LICENSE = 'diagnostics_and_tuning_pack'
      }
      steps {
         sh 'rake test'
      }
    }
    stage('Test 12.2 PDB without tuning pack') {
      environment {
        DB_VERSION = '12.2_PDB'
        MANAGEMENT_PACK_LICENSE = 'diagnostics_pack'
      }
      steps {
         sh 'rake test'
      }
    }
    stage('Test 12.2 PDB without diagnostics and tuning pack') {
      environment {
        DB_VERSION = '12.2_PDB'
        MANAGEMENT_PACK_LICENSE = 'none'
      }
      steps {
         sh 'rake test'
      }
    }
    stage('Docker stop 12.2 EE') {
      steps {
         sh '#docker stop oracle_12.2.0.1-ee'
         sleep 20
       }
    }

    stage('Docker start 12.2 SE PDB') {
      steps {
         sh 'docker start oracle_12.2.0.1-se2'
         sleep 20
       }
    }
    stage('Test 12.2 SE PDB without diagnostics and tuning pack') {
      environment {
        DB_VERSION = '12.2_SE_PDB'
        MANAGEMENT_PACK_LICENSE = 'none'
      }
      steps {
         sh 'rake test'
      }
    }
    stage('Test 12.2 SE PDB with Panorama-Sampler') {
      environment {
        DB_VERSION = '12.2_SE_PDB'
        MANAGEMENT_PACK_LICENSE = 'panorama_sampler'
      }
      steps {
         sh 'rake test'
      }
    }
    stage('Docker stop 12.2 SE PDB') {
      steps {
         sh 'docker stop oracle_12.2.0.1-se2'
         sleep 20
       }
    }


  }

  post {
    failure {
        mail to: 'Peter.Ramm@ottogroup.com',
                 subject: "Failed Pipeline: ${currentBuild.fullDisplayName}",
                 body: "Something is wrong with ${env.BUILD_URL}"
    }
  }
}
