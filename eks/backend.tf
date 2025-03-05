# Terraform backend configuration for AWS S3 bucket

#backend "s3" {
#  bucket          = "{{ aws_account_id }}-{{ aws_region }}-tfstate"
#  key             = "state/eks/{{ eks_name }}/terraform.tfstate"
#  region          = "{{ aws_region }}"
#  dynamodb_table  = "{{ aws_account_id }}-{{ aws_region }}-tflocks"
#  encrypt         = true
#}
