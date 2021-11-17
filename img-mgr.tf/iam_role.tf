# Create necessary Roles for IMG-MGR and attach
resource "aws_iam_role" "ssm_role" {
  name = "ssm_role"
  assume_role_policy = file("${path.module}/scripts/ec2assumerole.json")
}

resource "aws_iam_policy" "s3AccessPolicy" {
  name        = "s3AccessPolicy"
  description = "s3 policy"
  policy      = data.template_file.s3_bucket_template.rendered
}

resource "aws_iam_policy_attachment" "policy_attach" {
  name       = "img-mgr-policy-attachment"
  roles      = ["${aws_iam_role.ssm_role.name}"]
  policy_arn = aws_iam_policy.s3AccessPolicy.arn
}

resource "aws_iam_role_policy_attachment" "attach_ssm_role" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM"
}

resource "aws_iam_instance_profile" "img_mgr_profile" {
  name = "ssm_role_profile_-${random_id.random_id_suffix.hex}"
  role = aws_iam_role.ssm_role.name
}
