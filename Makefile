default:
	# Running in development mode:
	# First, the frontend is compiled and the server is run.
	# 
	# Use:
	# make run-dev
	# 
	# *************************************************************
	# 
	# Preparing for production deployment (building a Docker image)
	# Arguments:
	# address=https://my-app-hosting-service.com (e.g.)
	# image-name=app-image (e.g.)
	#
	# Use:
	# make prepare-deploy address=https://my-app-hosting-service.com image-name=app-image
	#
	# If no value is provided for the arguments, the default values ​​will be taken:
	# - address=http://localhost:8000
	# - image-name=test,
	# which is useful if you want to test the created image locally.

run-dev:
	sh scripts/dev_script.sh

prepare-deploy:
	sh scripts/deploy_script.sh $(address) $(image-name)
