# Running the Object and Zombies detection demo

In order to run the demo, here are the steps to follow (at a high-level):
1. Build the containers you will need
2. Start the private registry
3. Upload the containers (in case they are not yet available in the private registry
4. Start the various services
5. Visualize the output
6. Shutting down the demo (and restarting it)

Here are the detailed steps, one at the time, assuming you are running this from the Kubernetes master that has `kubectl` enabled for your user.

## Building the containers
There are two containers we need to build for the demo: `streamapp`, `streamapp-zombie`. There is enough in the repo to build and use a third one called `streamapp-file` but we're not using it. It was an experiment to replace the IP video stream by a video file (and it worked, so if you want to try, just ping [me](mailto:geoffroy.vancutsem@intel.com) for additional information).

```
$ sudo docker build -t localhost:30500/streamapp:latest -f Dockerfile.objects .
$ sudo docker build -t localhost:30500/streamapp-zombie:latest -f Dockerfile.zombies .
```

## Start the private registry (if not running yet)

```
$ kubectl create -f k8s/registry.yaml
$ kubectl get po # to verify it is running correctly
```

## Upload your containers to the registry

You will need to upload your containers to the private registry before starting the Kubernetes services and pods. Do this as follows:
```
$ sudo docker push localhost:30500/streamapp:latest
$ sudo docker push localhost:30500/streamapp-zombie:latest
```

## Start the various services

You are now nearly ready to start the services. Before doing so, make sure to update the [webcam.yaml](./k8s/webcam.yaml) file with the IP address of your web camera, e.g.:
```
        env:
          - name: IP_CAMERA
            value: 192.168.1.138
```

Once that's done, proceed as follows (in this order):
```
$ kubectl create -f k8s/webcam.yaml # this will start a couple of containers, one taking the video stream and putting it in an in-memory DB running in a different container
$ kubectl create -f k8s/detection.yaml # this will start the TensorFlow container doing the generic Object Recognition
$ kubectl create -f k8s/detection-zombies.yaml # this will start a second TensorFlow container that uses a pre-trained model that detects a person or a zombie
```

## Visualize the output
To view the output of the detection algorithm, open a couple of brower tabs/windows using the following URLs:
- **http://k8s-master-ip:3000/** -> generic object detection
- **http://k8s-master-ip:30700/** -> zombie/person detection

Replace the `k8s-master-ip` string above by the real IP address of your Kubernetes master.

Enjoy!

# Updating the pre-trained model

If you want to try a new, different pre-trained model for Zombies, please follow these steps:
1. Put the `*.pb` and `*.pbtxt` file (from the pre-trained model) in the [`zombies`](./zombies) folder
2. Modify the [detection_zombies.py](./detection_zombies.py) if needed. Specifically this section:
   ```
   PATH_TO_CKPT = "/streamapp/zombies/frozen_inference_graph.pb"
   PATH_TO_LABELS = "/streamapp/zombies/pascal_label_map.pbtxt"
   NUM_CLASSES = 2
   ```
   **Note:** you will need to deduct the correct value for `NUM_CLASSES` by looking inside the `*.pbtxt` file
3. Rebuild your `localhost:30500/streamapp-zombie:latest` container and push it to the private registry
   ```
   $ sudo docker build -t localhost:30500/streamapp-zombie:latest -f Dockerfile.zombies .
   $ sudo docker push localhost:30500/streamapp-zombie:latest
   
   ```
4. Restart the service
   ```
   $ kubectl delete -f k8s/detection-zombies.yaml
   $ kubectl create -f k8s/detection-zombies.yaml
   ```
You are now using the new pre-trained model.
