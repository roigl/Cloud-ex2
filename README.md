Welcome to Exercise 2 : Dynamic Workload 

Failure Modes and Solutions: 
  
  #1 - REDIS server is down 
  
       can be checked by "redis-cli monitor" or "redic-cli ping" if received ok/pong - server is up. 
        else should restart the server and check the redis config if necessary 
  
  #2 - workers aren't exsist 
     
      initiation of the first worker failed - try to run app.py again 
      incase of scaleup issue- check aws instances configurations. 
  
  #3 - REDIS confiuraion Failure
      
        check if relevant envarioment exsist in all instanses.
        the redis public IP should be the same in all instances
      
  #4 - AWS configuration  Failure
        
        check that workers get the key.pem and security group according to the app ec2.
        check aws configuration exists in app ec2 for creating new workers. 
        check security group allowed connection between instances. 
  
  #5 - worker is not terminated 
  
        may some work still run on worker or are aws commands still in process. 
        wait or check the status in aws dashboards.    
  
  #7 workers boundary  - 

      default set to 30 instances, you can change the limit on the auto scale global variables. 
      
  #8  result does not appear -
        
      check if a worker exists. 
      check if work is finished successfully. 
      check if the default time to save result is low (default set to 1000 seconds) 
  
  
  
