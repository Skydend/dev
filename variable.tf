variable "awn_vpc" {
type    = string
default = "10.0.0.0/16"
}

variable "subnet_a_ip" {
    type = string
    default = "10.0.2.0/24"
}

variable "subnet_b_ip" {
    type = string
    default = "10.0.3.0/24"
}

variable "test" {
    type = string
    default = "test"
}