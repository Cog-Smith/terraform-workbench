#---------------------------------
# required variables
#---------------------------------
variable "project" {
  description = "the project name for this bucket."
  type        = string
}

#---------------------------------
# s3 variables
#---------------------------------
variable "force_destroy" {
  description = "(Optional, Default:false) A boolean that indicates all objects (including any locked objects) should be deleted from the bucket so that the bucket can be destroyed without error."
  type        = bool
  default     = false 
}

#---------------------------------
# tag collection variables
#---------------------------------
variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}