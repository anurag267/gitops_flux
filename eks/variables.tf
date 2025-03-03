variable "aws_region" {
  type    = string
  default = "{{ aws_region }}"
}

variable "networking_tf_state_bucket" {
  type    = string
  default = "{{ tf_state_bucket }}"
}

variable "networking_tf_state_key" {
  type    = string
  default = "{{ tf_state_key }}"
}

variable "secrets_path_ado_ssh_key" {
  type    = string
  default = "{{ secrets_path_ado_ssh_key }}"
}

variable "eks_name" {
  type    = string
  default = "{{ eks_name }}"
}
