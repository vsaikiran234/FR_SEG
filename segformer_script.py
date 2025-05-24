import cv2
import torch
import numpy as np
from PIL import Image
from transformers import SegformerFeatureExtractor
from transformers import SegformerConfig, SegformerForSemanticSegmentation
import sys
import os
import time

# --- Load fine-tuned checkpoint ---
def load_custom_model(checkpoint_path):
    config = SegformerConfig.from_pretrained("nvidia/segformer-b0-finetuned-ade-512-512")
    config.num_labels = 5
    config.id2label = {str(i): f"class_{i}" for i in range(5)}
    config.label2id = {v: int(k) for k, v in config.id2label.items()}

    model = SegformerForSemanticSegmentation(config)
    state_dict = torch.load(checkpoint_path, map_location="cpu")["state_dict"]
    state_dict = {k.replace("model.", ""): v for k, v in state_dict.items()}
    model.load_state_dict(state_dict, strict=False)
    model.eval()
    return model

# --- Visualization ---
def prediction_to_vis(prediction):
    color_map = {
        0: (0, 0, 0),
        1: (255, 0, 0),
        2: (0, 255, 0),
        3: (0, 0, 255),
        4: (255, 255, 0),
    }
    vis = np.zeros(prediction.shape + (3,), dtype=np.uint8)
    for i, color in color_map.items():
        vis[prediction == i] = color
    return Image.fromarray(vis)

# --- Segmentation Overlay ---
def apply_segmentation_overlay(frame, model, feature_extractor):
    image = Image.fromarray(cv2.cvtColor(frame, cv2.COLOR_BGR2RGB))
    encoded_inputs = feature_extractor(image, return_tensors="pt")
    with torch.no_grad():
        outputs = model(**encoded_inputs)
    logits = outputs.logits
    predicted_mask = torch.argmax(logits, dim=1).cpu().numpy()[0]
    vis_mask = prediction_to_vis(predicted_mask).resize(image.size)
    vis_mask_np = np.array(vis_mask)
    return cv2.addWeighted(frame, 0.7, vis_mask_np, 0.3, 0)

# --- Process video ---


def process_video(input_video_path, output_video_path, model, feature_extractor, frame_size=(640, 480)):
    cap = cv2.VideoCapture(input_video_path)
    fps = cap.get(cv2.CAP_PROP_FPS)
    fourcc = cv2.VideoWriter_fourcc(*'mp4v')
    out = cv2.VideoWriter(output_video_path, fourcc, fps, frame_size)

    is_headless = os.environ.get("DISPLAY", "") == ""

    frame_count = 0
    while cap.isOpened():
        ret, frame = cap.read()
        if not ret:
            break

        frame = cv2.resize(frame, frame_size)
        start_time = time.time()

        overlay = apply_segmentation_overlay(frame, model, feature_extractor)

        # FPS calculation
        end_time = time.time()
        frame_time = end_time - start_time
        frame_fps = 1.0 / frame_time if frame_time > 0 else 0.0
        frame_count += 1
        print(f"[Frame {frame_count}] FPS: {frame_fps:.2f}")

        if not is_headless:
            cv2.imshow("Segmentation Output", overlay)
            if cv2.waitKey(1) & 0xFF == ord('q'):
                break

        out.write(overlay)

    cap.release()
    out.release()
    if not is_headless:
        cv2.destroyAllWindows()
    print(f"[✓] Processed video saved at {output_video_path}")


# --- MAIN ---
if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("Usage: python3 segformer_script.py <checkpoint_path> <input_video> <output_video>")
        sys.exit(1)

    checkpoint_path = sys.argv[1]
    input_video_path = sys.argv[2]
    output_video_path = sys.argv[3]

    if not os.path.exists(checkpoint_path):
        raise FileNotFoundError(f"Checkpoint not found: {checkpoint_path}")
    if not os.path.exists(input_video_path):
        raise FileNotFoundError(f"Input video not found: {input_video_path}")

    model = load_custom_model(checkpoint_path)
    feature_extractor = SegformerFeatureExtractor.from_pretrained("nvidia/segformer-b0-finetuned-ade-512-512")
    feature_extractor.do_reduce_labels = False

    process_video(input_video_path, output_video_path, model, feature_extractor)

