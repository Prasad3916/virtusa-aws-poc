import os
import io
import urllib.parse
import boto3
from PIL import Image

s3_client = boto3.client('s3')

def handler(event, context):
    """
    AWS Lambda function triggered by S3 ObjectCreated events under the 'uploads/' prefix.
    Generates a 150x150 thumbnail and uploads it to 'thumbnails/' prefix.
    """
    destination_prefix = os.environ.get('DESTINATION_PREFIX', 'thumbnails/')

    for record in event.get('Records', []):
        bucket = record['s3']['bucket']['name']
        key = urllib.parse.unquote_plus(record['s3']['object']['key'], encoding='utf-8')

        print(f"Processing object: {key} from bucket: {bucket}")

        # Skip if object is already a thumbnail to avoid recursion
        if key.startswith(destination_prefix):
            print(f"Object {key} is already in destination prefix. Skipping.")
            continue

        filename = os.path.basename(key)
        # Determine thumbnail destination key
        if key.startswith('uploads/'):
            sub_path = key[len('uploads/'):]
            thumb_key = f"{destination_prefix}{sub_path}"
        else:
            thumb_key = f"{destination_prefix}{filename}"

        try:
            # Download file from S3 into memory
            response = s3_client.get_object(Bucket=bucket, Key=key)
            content_type = response.get('ContentType', 'image/jpeg')
            image_bytes = response['Body'].read()

            # Open image with Pillow and create thumbnail
            image = Image.open(io.BytesIO(image_bytes))
            image.thumbnail((150, 150))

            # Save thumbnail to in-memory byte buffer
            buffer = io.BytesIO()
            img_format = image.format if image.format else 'JPEG'
            image.save(buffer, format=img_format)
            buffer.seek(0)

            # Upload thumbnail back to S3
            s3_client.put_object(
                Bucket=bucket,
                Key=thumb_key,
                Body=buffer,
                ContentType=content_type
            )

            print(f"Successfully generated and uploaded thumbnail to: {thumb_key}")

        except Exception as e:
            print(f"Error processing {key}: {str(e)}")
            raise e

    return {
        'statusCode': 200,
        'body': 'Thumbnail generation complete'
    }
