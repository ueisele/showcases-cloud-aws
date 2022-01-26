#################################
# Pod with EFS PV on Fargate    #
#################################

locals {
    pv_name = "pvc-fargate-${uuid()}"
}

data "aws_efs_file_system" "by_tag" {
  tags = {
    Name = "${var.environment}-${var.module}-efs-pod-storage"
  }
}

resource "aws_efs_access_point" "efs-fargate" {
  file_system_id = data.aws_efs_file_system.by_tag.id
  posix_user {
    uid = 10000
    gid = 10000
  }
  root_directory {
    path = "/${local.pv_name}"
    creation_info {
      owner_gid = 10000
      owner_uid = 10000
      permissions = 700
    }
  }
  tags = {
    Name = local.pv_name
    Environment = var.environment
    Terraform = "true"
  }
}

resource "kubernetes_persistent_volume_v1" "efs-fargate" {
  metadata {
    name = local.pv_name
    annotations = {
        terraform = true
    }
  }
  spec {
    capacity = {
      storage = "5Gi"
    }
    volume_mode = "Filesystem"
    access_modes = ["ReadWriteMany"]
    storage_class_name = "efs-fargate-static" # value does not matter, must only be equal to pvc
    persistent_volume_source {
      csi {
        driver = "efs.csi.aws.com"
        volume_handle = "${data.aws_efs_file_system.by_tag.id}::${aws_efs_access_point.efs-fargate.id}" 
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim_v1" "efs-fargate" {
  metadata {
    name = "efs-fargate-claim"
    namespace = "default"
    annotations = {
        terraform = true
    }
  }
  spec {
    access_modes = ["ReadWriteMany"]
    storage_class_name = "efs-fargate-static" # value does not matter, must only be equal to pv
    resources {
      requests = {
        storage = "5Gi"
      }
    }
    volume_name = "${kubernetes_persistent_volume_v1.efs-fargate.metadata.0.name}"
  }
}

resource "kubernetes_pod_v1" "efs-fargate" {
  metadata {
    name = "efs-fargate-pod"
    namespace = "default"
    annotations = {
        terraform = true
    }
  }
  spec {
    container {
      image = "centos"
      name  = "app"
      env {
        name  = "POD_NAME"
        value_from {
          field_ref {
            field_path = "metadata.name"
          }
        }
      }
      command = ["/bin/sh"]
      args = ["-c", "while true; do echo $${POD_NAME}: $(date -u) >> /data/out; sleep 5; done"]
      volume_mount {
        name = "persistent-storage"
        mount_path = "/data"
      }
    }
    volume {
      name = "persistent-storage"
      persistent_volume_claim {
          claim_name = "${kubernetes_persistent_volume_claim_v1.efs-fargate.metadata.0.name}"
      }
    }
  }
}
