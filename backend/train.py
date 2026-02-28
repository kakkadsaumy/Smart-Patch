import os
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader
from torchvision import models
from tqdm import tqdm
from sklearn.metrics import accuracy_score
from utils import ImageFolderDataset, train_transform, eval_transform

DATA_DIR = "../images"
TRAIN_DIR = os.path.join(DATA_DIR, "train")
TEST_DIR = os.path.join(DATA_DIR, "test")

BATCH_SIZE = 16
NUM_EPOCHS = 6
LR = 1e-4

MODEL_PATH = "model/model.pt"

def get_dataloaders():
    train_ds = ImageFolderDataset(TRAIN_DIR, train_transform)
    test_ds = ImageFolderDataset(TEST_DIR, eval_transform)

    train_loader = DataLoader(train_ds, batch_size=BATCH_SIZE, shuffle=True)
    test_loader = DataLoader(test_ds, batch_size=BATCH_SIZE, shuffle=False)

    return train_loader, test_loader, train_ds.class_to_idx


def build_model(num_classes):
    model = models.mobilenet_v2(pretrained=True)
    in_features = model.classifier[1].in_features
    model.classifier[1] = nn.Linear(in_features, num_classes)
    return model


def evaluate(model, loader, device):
    model.eval()
    all_preds = []
    all_labels = []

    with torch.no_grad():
        for images, labels in loader:
            images = images.to(device)
            labels = labels.to(device)
            outputs = model(images)
            _, preds = torch.max(outputs, 1)
            all_preds.extend(preds.cpu().numpy())
            all_labels.extend(labels.cpu().numpy())

    return accuracy_score(all_labels, all_preds)


def train():
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    train_loader, test_loader, class_to_idx = get_dataloaders()

    model = build_model(len(class_to_idx))
    model.to(device)

    criterion = nn.CrossEntropyLoss()
    optimizer = optim.Adam(model.parameters(), lr=LR)

    best_acc = 0

    for epoch in range(NUM_EPOCHS):
        model.train()
        loop = tqdm(train_loader, desc=f"Epoch {epoch+1}/{NUM_EPOCHS}")

        for images, labels in loop:
            images = images.to(device)
            labels = labels.to(device)

            optimizer.zero_grad()
            outputs = model(images)
            loss = criterion(outputs, labels)
            loss.backward()
            optimizer.step()

            loop.set_postfix(loss=loss.item())

        acc = evaluate(model, test_loader, device)
        print(f"Validation Accuracy: {acc:.4f}")

        if acc > best_acc:
            best_acc = acc
            os.makedirs("model", exist_ok=True)
            torch.save({
                "model_state_dict": model.state_dict(),
                "class_to_idx": class_to_idx
            }, MODEL_PATH)
            print("Saved best model")

    print("Training complete. Best accuracy:", best_acc)


if __name__ == "__main__":
    train()