"""
Hello World Glue Job - Testing Infrastructure
"""

import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from datetime import datetime
import boto3

args = getResolvedOptions(sys.argv, ['JOB_NAME', 'output_bucket'])

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

print("=" * 80)
print("🎉 Hello from AWS Glue - etl-scomics!")
print("=" * 80)
print(f"Job Name: {args['JOB_NAME']}")
print(f"Output Bucket: {args['output_bucket']}")
print(f"Timestamp: {datetime.now()}")
print("=" * 80)

# Create test DataFrame
data = [
    ("Hello", "World", 1),
    ("Glue", "Pipeline", 2),
    ("etl-scomics", "Testing", 3)
]

df = spark.createDataFrame(data, ["col1", "col2", "col3"])

print("\n📊 Sample DataFrame:")
df.show()

# Write to S3
output_path = f"{args['output_bucket']}/hello_world_output/"
print(f"\n💾 Writing output to: {output_path}")

df.write.mode("overwrite").parquet(output_path)

# Success marker
s3 = boto3.client('s3')
bucket_name = args['output_bucket'].replace('s3://', '').split('/')[0]
success_key = 'hello_world_output/_SUCCESS.txt'

s3.put_object(
    Bucket=bucket_name,
    Key=success_key,
    Body=f"Job completed successfully at {datetime.now()}".encode()
)

print("\n✅ Job completed successfully!")
print("=" * 80)

job.commit()
