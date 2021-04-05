# PHALT (Payload Harvest And Load Tool)

This application serves as a proxy to download files from a remote storage location (CEPH), access our IIIF image server and IIIF presentation manifests.

## API (Incomplete description)

### Download 
Downloads files from remote storage location, in our case CEPH via an S3 protocol.

`GET /download/:bucket/:file`

#### Parameters

| Name        | In   | Description | Default |
| ----------- | --   | ----------- | |
| filename    | path | filename (without extension) to override given filename | given filename |
| disposition | path | whether the file should be downloaded or inline | attachment |



