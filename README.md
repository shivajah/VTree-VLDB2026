



# VTree: A LSM-Native Vector Index for Analytical Databases

This repository contains the prototype accompanying our VLDB publication on ``VTree: A LSM-Native Vector Index for Analytical Databases".  
The implementation is built on top of [Apache AsterixDB](https://asterixdb.apache.org/) and extends it with columnar storage and vector indexing support.

---

# Requirements

Before building the project, install:

- **Maven** (3.3.9 or newer)
- **Ansible** (used for cluster deployment)

No additional JVM distributions or code-generation runtimes are required.

---

## What is AsterixDB?

AsterixDB is a BDMS (Big Data Management System) with a rich feature set that sets it apart from other Big Data platforms.  Its feature set makes it well-suited to modern needs such as web data warehousing and social data storage and analysis. AsterixDB has:

- **Data model**  

A semistructured NoSQL style data model ([ADM](https://ci.apache.org/projects/asterixdb/datamodel.html)) resulting from
extending JSON with object database ideas
- **Query languages**  

An expressive and declarative query language ([SQL++](http://asterixdb.apache.org/docs/0.9.7/sqlpp/manual.html) that supports a broad range of queries and analysis over semistructured data
- **Scalability**  

A parallel runtime query execution engine, Apache Hyracks, that has been scale-tested on up to 1000+ cores and 500+ disks
- **Native storage**  

Partitioned LSM-based data storage and indexing to support efficient ingestion and management of semistructured data
- **External storage**  

Support for query access to externally stored data (e.g., data in HDFS) as well as to data stored natively by AsterixDB
- **Data types**  

A rich set of primitive data types, including spatial and temporal data in addition to integer, floating point, and textual data
- **Indexing**  

Secondary indexing options that include B+ trees, R trees, and inverted keyword (exact and fuzzy) index types
- **Transactions**  

Basic transactional (concurrency and recovery) capabilities akin to those of a NoSQL store

Learn more about AsterixDB at its [website](http://asterixdb.apache.org).

## Build from source

To build AsterixDB from source, you should have a platform with the following:

- A Unix-ish environment (Linux, OS X, will all do).
- git
- Maven 3.3.9 or newer.
- JDK 11 or newer.
- Python 3.6+ with pip and venv

Instructions for building the master:

- Checkout AsterixDB master:
  ```
    $git clone https://github.com/apache/asterixdb.git
  ```
- Build AsterixDB master:
  ```
    $cd asterixdb
    $mvn clean package -DskipTests
  ```

## Run the build on your machine

Here are steps to get AsterixDB running on your local machine:

- Start a single-machine AsterixDB instance:
  ```
    $cd asterixdb/asterix-server/target/asterix-server-*-binary-assembly/apache-asterixdb-*-SNAPSHOT
    $./opt/local/bin/start-sample-cluster.sh
  ```
- Good to go and run queries in your browser at:
  ```
    http://localhost:19006
  ```
- Read more [documentation](https://ci.apache.org/projects/asterixdb/index.html) to learn the data model, query language, and how to create a cluster instance.

---

## Experiment Configuration

This section describes how to deploy an AsterixDB cluster on AWS for running experiments.

### 1. Provision EC2 Instances

Launch **m8id.xlarge** instances in your preferred AWS region. Ensure sufficient instances for your cluster topology (one Cluster Controller node and one or more Node Controller nodes).

### 2. Deploy the AsterixDB Binary

Build the project locally, then copy the binary assembly to each EC2 instance:

```bash
# Build locally first
cd asterixdb && mvn clean package -DskipTests

# Copy the binary to each instance (replace <instance-ip> with the instance's public or private IP)
scp -r asterixdb/asterix-server/target/asterix-server-*-binary-assembly/apache-asterixdb-*-SNAPSHOT ec2-user@<instance-ip>:~/
```

Repeat the copy step for every instance that will participate in the cluster.

### 3. Configure IAM and Security

- **IAM**: Attach an IAM role to each EC2 instance with permissions for S3 access (read/write to your bucket) and any other required AWS services.
- **Security groups**: Configure security groups so that instances can communicate with each other over the required ports (e.g., 19004 for NC API, 9090 for NC service, and any ports used by the Cluster Controller). Ensure inbound rules allow traffic from the other cluster members.

### 4. Create an S3 Bucket

Create an S3 bucket in the **same AWS region** as your EC2 instances. Configure the bucket and IAM so that:

- EC2 instances have read/write access to the bucket via their IAM role.
- Security and network settings allow the instances to reach the bucket (e.g., VPC endpoints or public access as appropriate for your setup).

### 5. Prepare Each Instance

On **every** instance (CC and NC nodes), run the prepare script to set up storage and dependencies:

```bash
cd ~/apache-asterixdb-*-SNAPSHOT/opt/local/bin
./prepare-instance.sh [device]
```

The script formats and mounts an EBS volume at `/mnt/instance` and installs Java 21. If you have multiple data devices, pass the device path (e.g., `/dev/nvme1n1`) as an argument.

### 6. Configure cc.conf

On the Cluster Controller (CC) node, edit `opt/local/conf/cc.conf`:

- **`[nc/1]`, `[nc/2]`, etc.**: Set `address` to the IP of each Node Controller instance.
- **`[cc]`**: Set `address` to the IP of the CC node (typically the node you will query).
- **`[common]`**: Set `cloud.storage.bucket` to your S3 bucket name and `cloud.storage.region` to the AWS region where the bucket resides.

Ensure this configuration is consistent across all nodes if they use a shared config.

### 7. Start the Cluster

- **On the CC node** (the main cluster controller):

  ```bash
  cd ~/apache-asterixdb-*-SNAPSHOT/opt/local/bin
  ./start-sample-cluster.sh
  ```

- **On each NC node** (all other nodes):

  ```bash
  cd ~/apache-asterixdb-*-SNAPSHOT/opt/local/bin
  ./start-sample-node.sh
  ```

Start the CC node first, then start the NC nodes. The NC nodes will listen for the CC to connect and push configuration.

---

## Dataset Creation

Use `dataset-creation/amplify_dataset.py` to generate an amplified JSONL dataset with embeddings.

### 1. Install Python dependencies

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install sentence-transformers pandas
```

Optional dependencies:

```bash
pip install orjson
pip install boto3 smart_open[s3]
```

### 2. Run the script (local output)

```bash
python3 dataset-creation/amplify_dataset.py /path/to/input.csv -o amplified_output
```

Quick test with a small sample:

```bash
python3 dataset-creation/amplify_dataset.py /path/to/input.csv -o amplified_output --limit 10
```

### 3. (Optional) Stream output directly to S3

```bash
python3 dataset-creation/amplify_dataset.py /path/to/input.csv -o out --s3-bucket my-bucket --s3-prefix amplified/
```

## GIST‑960 Example (Using the `open-vdb/gist-960-euclidean` Dataset)

This example demonstrates how to load the **GIST‑960** dataset from Hugging Face and build a vector index in AsterixDB using the columnar storage format.

Dataset:  
[https://huggingface.co/datasets/open-vdb/gist-960-euclidean](https://huggingface.co/datasets/open-vdb/gist-960-euclidean)

---

### 1. Create Dataverse and Dataset (Column Storage)

```sql
DROP DATAVERSE VectorTest IF EXISTS;
CREATE DATAVERSE VectorTest;
USE VectorTest;

CREATE TYPE OpenType AS {
  k: uuid
};

CREATE DATASET GIST(OpenType)
PRIMARY KEY k AUTOGENERATED
WITH {
  "storage-format": { "format": "column" }
};

USE VectorTest;
```

```sql
LOAD DATASET GIST USING localfs (
  ("path" = "asterix_nc1:///path/to/dataset.jsonl"),
  ("format" = "json")
);
```

```sql
USE VectorTest;

DROP INDEX GIST.ix1 IF EXISTS;

CREATE VECTOR INDEX ix1 ON GIST(embedding VECTOR)
WITH {
  "dimension": 960,
  "train_list_number": 10000,
  "num_clusters": 300,
  "similarity": "cosine similarity"
};
```

```sql
USE VectorTest;

FROM GIST m
LET qvec = [ /* 960-dimensional query vector */ ]
SELECT m.k
ORDER BY ANN_DISTANCE(m.embedding, qvec, "cosine similarity")
LIMIT 10;
```

## Documentation

To generate the documentation, run asterix-doc with the generate.rr profile in maven, e.g  `mvn -Pgenerate.rr ...`
Be sure to run `mvn package` beforehand or run `mvn site` in asterix-lang-sqlpp to generate some resources that
are used in the documentation that are generated directly from the grammar.

- [master](https://ci.apache.org/projects/asterixdb/index.html) |
[0.9.7](http://asterixdb.apache.org/docs/0.9.7/index.html) |
[0.9.6](http://asterixdb.apache.org/docs/0.9.6/index.html) |
[0.9.5](http://asterixdb.apache.org/docs/0.9.5/index.html) |
[0.9.4.1](http://asterixdb.apache.org/docs/0.9.4.1/index.html) |
[0.9.4](http://asterixdb.apache.org/docs/0.9.4/index.html) |
[0.9.3](http://asterixdb.apache.org/docs/0.9.3/index.html) |
[0.9.2](http://asterixdb.apache.org/docs/0.9.2/index.html) |
[0.9.1](http://asterixdb.apache.org/docs/0.9.1/index.html) |
[0.9.0](http://asterixdb.apache.org/docs/0.9.0/index.html)

## Community support

- **Users**  

maling list: [users@asterixdb.apache.org](mailto:users@asterixdb.apache.org)  

Join the list by sending an email to [users-subscribe@asterixdb.apache.org](mailto:users-subscribe@asterixdb.apache.org)  

- **Developers and contributors**  

mailing list:[dev@asterixdb.apache.org](mailto:dev@asterixdb.apache.org)  

Join the list by sending an email to [dev-subscribe@asterixdb.apache.org](mailto:dev-subscribe@asterixdb.apache.org)

