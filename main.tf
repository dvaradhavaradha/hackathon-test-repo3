variable "project_user_map" {
  description = "Map of project ids to user lists"
  type        = map(list(string))
  default     = {
    "project-1" = ["user1", "user2"]
    "project-2" = ["user3", "user4"]
    # add more projects as needed
  }
}

provider "google" {
  credentials = var.gcp-creds
}


variable "gcp-creds" {
default= ""
}

resource "google_project" "project" {
  for_each = var.project_user_map

  name       = each.key
  project_id = each.key
  folder_id  = "256082523262"

  billing_account = "0175F4-91F155-9AB0E8"
}

locals {
  project_user_list = flatten([
    for project, users in var.project_user_map : [
      for user in users : {
        project = project
        user    = user
      }
    ]
  ])
}

resource "google_project_iam_member" "project" {
  for_each = { for pu in local.project_user_list : "${pu.project}-${pu.user}" => pu }

  project = each.value.project_user_map
  role    = "roles/editor" # You can specify any other role

  member = "user:${each.value.user}"
}

resource "random_integer" "suffix" {
  for_each = google_project.project

  min = 1000
  max = 9999
}

resource "google_container_cluster" "cluster" {
  for_each = google_project.project

  name     = "${each.key}-cluster-${random_integer.suffix[each.key].result}"
  location = "us-central1"
  project  = each.key

  initial_node_count = 3

  master_auth {
    client_certificate_config {
      issue_client_certificate = false
    }
  }
}


resource "google_sql_database_instance" "instance" {
  for_each = google_project.project

  name     = "${each.key}-sql-${random_integer.suffix[each.key].result}"
  project  = each.key
  region   = "us-central1"

  database_version = "POSTGRES_13" # specify the database version here

  settings {
    tier = "db-f1-micro"
  }
}


resource "google_sql_user" "users" {
  for_each = local.project_user_list

  name     = each.value.user
  instance = google_sql_database_instance.instance[each.value.project].name
  password = "password" # TODO: Replace with a secure method of supplying the password
}
