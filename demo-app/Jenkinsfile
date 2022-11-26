#!/usr/bin/env groovy

pipeline {

  agent any
  stages {
    stage('Build') {
      steps {
       configFileProvider([configFile(fileId: 'maven-settings-file', variable: 'MAVEN_SETTINGS')]) {
        withCredentials([usernamePassword(credentialsId: 'dis-functional', usernameVariable: 'USERNAME', passwordVariable: 'PASSWORD')]) {

             sh """
              mvn -version
              mvn -X -s $MAVEN_SETTINGS -Drevision=latest -U clean  deploy

              echo "STARTED: Docker Nexus Login"
              docker login localhost:5000 --username ${USERNAME} --password ${PASSWORD}

             echo "STARTED: Docker image build"
             docker build  -t localhost:5000/demo-app:latest .

             echo "STARTED: Docker images push"
             docker push localhost:5000/demo-app:latest
			 
			 echo "Remove image from local machine"
			 docker rmi localhost:5000/demo-app:latest
			 
			 
              """
			  }        
           }
       }
    }

    stage('Deploy') {
      steps {
	    script {
		  withCredentials([usernamePassword(credentialsId: 'dis-functional', usernameVariable: 'USERNAME', passwordVariable: 'PASSWORD')]) {
          sh """
		   
           ssh ubuntu@10.0.0.140 bash -c "'
             
			sudo docker ps -a -q --filter ancestor=10.0.0.207:5000/demo-app:latest |xargs -r sudo docker stop
			sudo docker ps -a -q -f status=exited|xargs -r sudo docker rm -v
			sudo docker images --format "{{.ID}} {{.Repository}}"|grep demo-app|xargs -r sudo docker rmi -f
			
			sudo docker login 10.0.0.207:5000 -u=${USERNAME} -p=${PASSWORD}
			sudo docker run -itd  --name demo-app -p 8000:8000 10.0.0.207:5000/demo-app:latest
           '"       
		   
          """
         }
        }
	   }	
    }
 }
}

