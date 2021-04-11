//
//  ContentView.swift
//  MLKitSwiftUI Example
//
//  Created by Dohyun Ji on 2021/04/11.
//

import SwiftUI


struct ContentView: View {
    @StateObject var viewModel = ImageSegmentViewModel()
    
    var body: some View {
        VStack(spacing: 32) {
            imageView(for: viewModel.segmentedImage)
            Button(action: viewModel.choosePhoto, label: {
                Text(viewModel.isProcessing ? "Processing..." : "Choose Photo")
            })
        }
        .fullScreenCover(isPresented: $viewModel.isPresentingImagePicker, content: {
            ImagePicker(sourceType: viewModel.sourceType, completionHandler: viewModel.didSelectImage)
        })
    }
    
    @ViewBuilder
    func imageView(for image: UIImage?) -> some View {
        if let image = image {
            Image(uiImage: image).resizable().scaledToFill()
        }
        EmptyView()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ContentView()
        }
    }
}
