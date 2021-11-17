deploy-dev:
	DEPLOY_ENVIRONMENT=dev runway deploy
deploy-common:
	DEPLOY_ENVIRONMENT=common runway deploy
deploy-img-mgr:
	DEPLOY_ENVIRONMENT=dev runway deploy
destroy-dev:
	DEPLOY_ENVIRONMENT=dev runway destroy
destroy-common:
	DEPLOY_ENVIRONMENT=common runway destroy
destroy-img-mgr:
	DEPLOY_ENVIRONMENT=dev runway destroy
