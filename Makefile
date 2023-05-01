# .envファイルを読み込み
# include の変数セットが難しいので上の階層を
include .env
templateFile = $(stackTemplatePath)/$(targetStackTemplate).yaml

# プロファイル
profile = $(Profile)
# リージョン
region = $(Region)

# makeコマンドの引数をテストしたいとき
test:
	echo $(name)-$(shell date +%s)

directory = ./s3

# localのs3フォルダーの存在確認
# なければs3フォルダーを作成する
check-directory: | $(directory)
	@echo "Continuation regardless of existence of $(directory)"

$(directory):
	@echo "Folder $(directory) does not exist"
	mkdir -p $@

deploy:
	sam deploy

# インタラクティブにデプロイができる
# samconfig.toml（configが予め設定済みのファイル）があればsam deployだけデプロイができる
deploy-guide:
	sam deploy --guided

# sam cliを使ってのbuild
# template.yamlの環境変数を変えたらbuildをしておかないとlocalでendpointを実行したときに環境変数が反映されない
build:
	sam build

# localで起動ができる
start:
	sam local start-api

# 修正を監視する
# make startを行ったあと、別のターミナル画面でやるといい
watch:
	npm run watch

# 公式からdynamoDBのimageでdocker composeを起動する
docker-build-up:
	docker-compose up --build

docker-up:
	docker-compose up

####### s3 #######

# s3のbucket一覧を取得する
list-bucket:
	aws s3 ls

# s3のbucketを作成する（regionはprofileのdefault）
# 末尾をtimestampにしているのはdirectory名が被って作成できない時があるため
# 例； example-lambda-${currentTimeStamp}
create-bucket:
	aws s3 mb s3://$(name)-$(shell date +%s)

# localのs3フォルダーにs3にアップするためのcompileされたlambdaコードを配置する
sync-local:
	cd scripts && node syncBucket.js -z --yamlPath="$(yamlPath)"

# localのs3が空だからといってcloudのs3のbucketが空になることはない
sync-bucket:
	make check-directory
	aws s3 sync s3 s3://$(bucketName)

# buildやsync-local、sync-bucketを順番に実行するのが面倒なのでひとまとめにしたコマンド
# src配下のソースコードをcompileした後に実行する
sync-deploy:
	make build
	make sync-local yamlPath="$(yamlPath)"
	make sync-bucket bucketName="$(bucketName)"

# 既存のtemplate.yamlからs3のpathを参照したtemplateのyamlを生成してくれる
# make deploy-package bucketName=""
create-package-yaml:
	sam package \
		--template-file template.yaml \
		--s3-bucket $(bucketName) \
		--output-template-file output.yaml \
		--profile $(profile) \
		--region $(region)

####### deploy #######
# スタックを作成するときに実行するコマンド

# s3のpathを参照したtemplateのyamlを基にsamコマンド経由でdeployを行う
# make sam-deploy-package stackName=""
sam-deploy-package:
	sam deploy \
		--template-file output.yaml \
		--stack-name $(stackName) \
		--capabilities CAPABILITY_IAM \
		--profile $(profile) \
		--region $(region)

# s3のpathを参照したtemplateのyamlを基にcloudformationコマンド経由でdeployを行う
# make deploy-package stackName=""
deploy-package:
	aws cloudformation deploy \
		--stack-name $(stackName)-lambda \
		--template-file output.yaml \
		--capabilities CAPABILITY_IAM \
		--profile $(profile) \
		--region $(region)

####### update #######
# すでにスタックがあってバージョン情報などを更新する時

# バージョン情報や環境変数などの要素を更新したいときに実行する
# change-set-nameはversion1.0.1などの小数点は入力できない
update-package:
	aws cloudformation create-change-set \
		--stack-name $(stackName)-lambda \
		--template-body file://output.yaml \
		--change-set-name $(changeSetName) \
		--capabilities CAPABILITY_IAM \
		--profile $(profile) \
		--region $(region)

# スタックを更新するための実行コマンド
# 事前に同じchangeSetNameをupdate-packageで行なってからexecute-update-packageを実行することができる
execute-update-package:
	aws cloudformation execute-change-set \
		--stack-name $(stackName)-lambda \
		--change-set-name $(changeSetName) \
		--profile $(profile) \
		--region $(region)

# cloudのs3にアップロードする事前準備
# version情報を切るようにlocalのs3にsam buildした成果物を配置する
#prepare-bucket:
#	rsync -a .aws-sam/build/* ./s3 --exclude "template.yaml"

#zip-bucket:
#	cd s3/$(target) && zip -r ../$(target).zip *
