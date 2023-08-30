variable "region" {
  description = "Region to deploy all resources"
  default     = "us-west-2"
}

variable "aws_access_key" {
  description = "AWS Credentials"
  default = "XXXXXXXX"
}

variable "aws_secret_access_key" {
  description = "AWS Credentials"
  default = "XXXXXXX"
}

variable "ado_pat" {
  description = "ADO PAT"
  default = "XXXXXXXXX"
}
