output "lake_bucket_name" { value = module.lake_storage.bucket_name }
output "rds_endpoint" { value = module.rds.endpoint }
output "kafka_public_ip" { value = module.ec2_kafka.public_ip }
output "kafka_bootstrap_server" { value = "${module.ec2_kafka.public_ip}:9092" }
output "karapace_registry_url" { value = "http://${module.ec2_kafka.public_ip}:8081" }
output "estimated_cost_note" { value = "Destroy this lab after use. Budget alerts do not stop resources automatically." }
