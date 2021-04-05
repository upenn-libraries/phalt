# PHALT (Payload Harvest And Load Tool)

This application serves as a proxy to download files from a remote storage location (CEPH), access our IIIF image server and access IIIF presentation manifests.

## API (Incomplete description)

### Download 
Downloads files from remote storage location, in our case CEPH via an S3 protocol. Changes filename and disposition if values are passed in as query parameters.

`GET /download/:bucket/:file`

#### Parameters

| Name        | In    | Description | Default |
| ----------- | ----- | ----------- | ------- |
| bucket | path | bucket name ||
| file | path | filename ||
| filename    | query | filename (without extension) to override given filename | `file` in path parameter |
| disposition | query | whether the file should be downloaded or inline | attachment |



