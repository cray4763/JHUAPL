# Define variables for the bucket and drive names
variable "bucket_name" {
  type        = string
  description = "Name of the S3 bucket"
}

variable "drive_name" {
  type        = string
  description = "Name of the GCP drive"
}

# Create an S3 bucket
resource "aws_s3_bucket" "example_bucket" {
  bucket = var.bucket_name

  # Enable versioning for the S3 bucket
  versioning {
    enabled = true
  }
}

# Create a GCP drive
resource "google_drive_drive" "example_drive" {
  name = var.drive_name
}

# Create a Jupyter Notebook instance
resource "google_compute_instance" "example_instance" {
  name         = "example-instance"
  machine_type = "n1-standard-1"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-10"
    }
  }

  network_interface {
    network = "default"
    access_config {
      // Allocate a ephemeral IP to the instance
    }
  }

  metadata = {
    # Install Jupyter Notebook and dependencies
    "google-logging-enabled" = "true"
    "notebook-install-script-url" = "https://raw.githubusercontent.com/example/jupyter-notebook-installer/main/install.sh"
  }

  # Define a startup script that mounts the S3 bucket and GCP drive
  metadata_startup_script = <<-EOF
    #!/bin/bash
    
    # Mount the S3 bucket
    sudo apt-get update
    sudo apt-get -y install s3fs
    sudo echo ${aws_s3_bucket.example_bucket.bucket}: /mnt/s3bucket fuse.s3fs _netdev,allow_other 0 0 >> /etc/fstab
    sudo mkdir /mnt/s3bucket
    sudo mount /mnt/s3bucket
    
    # Mount the GCP drive
    sudo apt-get -y install davfs2
    sudo echo "https://www.googleapis.com/drive/v3/files/${google_drive_drive.example_drive.id}?alt=media" >> /etc/davfs2/secrets
    sudo echo "/mnt/gcpdrive davfs user,noauto,rw 0 0" >> /etc/fstab
    sudo mkdir /mnt/gcpdrive
    sudo mount /mnt/gcpdrive
  EOF

  # Allow incoming HTTP traffic to the instance
  tags = {
    http-server = "true"
  }
}

# Output the Jupyter Notebook instance's public IP address
output "jupyter_notebook_ip" {
  value = google_compute_instance.example_instance.network_interface[0].access_config[0].nat_ip
}