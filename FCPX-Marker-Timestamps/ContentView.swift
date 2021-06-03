//
//  ContentView.swift
//  FCPX-Marker-Timestamps
//
//  Created by Jaryd Meek on 6/2/21.
//

import SwiftUI

//Handler to actually process the FCPX XML File
//I could treat this as an actual xml file, but in this case since the xml is so basic, it will be faster to just process it as a string.
class dataHandler {
    var markers:[marker] = []
    var start:Int = -1
    var frameRate:Double = 0
    
    struct marker {
        var seconds:Int = 0
        var frames:Int = 0
        var name:String = ""
        let id = UUID()
    }
    
    func divideNums(input: String) -> Double {
        let value = input.dropLast()
        var firstNumStr = value[...value.firstIndex(of: "/")!]
        var secondNumStr = value[value.firstIndex(of: "/")!...]
        firstNumStr.removeLast()
        secondNumStr.removeFirst()
        if let firstNum = Double(firstNumStr), let secondNum = Double(secondNumStr) {
            return firstNum/secondNum
        } else {
            return -1
        }
    }
    
    func openFile(URL: String) -> Bool {
        markers = []
        if let contents = try? String(contentsOfFile: String(URL.dropFirst(7))) {
            //FRAME RATE
            if let range = contents.range(of: "frameDuration") {
                let index = contents.index(range.upperBound, offsetBy: 2)
                var temp = contents[index...contents[index...].firstIndex(of: "\"")!]
                temp.removeLast(1)
                frameRate = (Double(round(1000*(1/(divideNums(input: String(temp)))))/1000))
                var current = contents[index...]
                //START VALUE
                if let range2 = contents.range(of: "<spine>") {
                    current = contents[range2.upperBound...]
                }
                if let range3 = current.range(of: " start=\"") {
                    var temp = contents[range3.upperBound...contents[range3.upperBound...].firstIndex(of: "\"")!]
                    temp.removeLast(2)
                    start = Int(temp) ?? -1
                    current = current[range3.upperBound...]
                }
                //BEGIN MARKERS
                
                while current.contains("<marker start=\""){
                    let currIndex = current.range(of: "<marker start=\"")!.upperBound
                    var temp = current[currIndex...]
                    //print(temp)
                    temp = temp[...temp.firstIndex(of: "s")!]
                    let dividedNums = (divideNums(input: String(temp))-Double(start))
                    let decimal = dividedNums.truncatingRemainder(dividingBy: 1)
                    let seconds = Int(dividedNums)
                    let frames = Int(round(decimal*frameRate))
                    
                    let valIndex = current.range(of: " value=\"")!.upperBound
                    let endRange = current.range(of: "\"/>")!
                    var value = current[valIndex...endRange.lowerBound]
                    value.removeLast()
                    
                    let tempMarker = marker(seconds: seconds, frames: frames, name: String(value))
                    markers.append(tempMarker)
                    current = current[endRange.upperBound...]
                }
                print(markers)
            } else {
                return false
            }
            return true
        } else {
            return false
        }
    }
    func getDataString(URL: String) -> String {
        print("yo")
        var storage = ""
        if data.openFile(URL: URL) {
            for marker in markers {
                storage += "\(marker.seconds):\(marker.frames) - \(marker.name)\n"
            }
            return storage
        } else {
            return "There was an error loading the data"
        }
    }
}


//Button Style to make life easier
struct MainButton: ButtonStyle {
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .foregroundColor(Color.white)
            .background(configuration.isPressed ? Color.gray : Color.accentColor)
            .cornerRadius(6)
    }
}

//Instantiate the XML Handler

var data = dataHandler()

struct ContentView: View {
    @State var showFilePicker = false
    @State var openURL:String = "/No File Selected"
    
    @State var loadedData = false
    
    @State var addFrames:Bool = false
    @State var testing = ""
    
    func openFile() {
        let open = NSOpenPanel()
        open.canChooseFiles = true
        open.canChooseDirectories = false
        open.allowsMultipleSelection = false
        open.allowedFileTypes = ["fcpxml"]
        open.begin { response in
            if response == NSApplication.ModalResponse.OK, let fileUrl = open.url {
                openURL = fileUrl.absoluteString
            }
        }
    }
    //MAIN VIEW
    var body: some View {
        GeometryReader { metrics in
            VStack {
                Text("Final Cut Pro X\n Marker To Timestamps")
                    .padding()
                    .multilineTextAlignment(.center)
                    .font(.largeTitle)
                Text(openURL[openURL.index(openURL.lastIndex(of: "/")!,offsetBy: 1)...])
                Button(action: {
                    openFile()
                }, label: {
                    Text("Select File")
                        .padding(.top, 10)
                        .padding(.bottom, 10)
                        .padding(.leading, 20)
                        .padding(.trailing, 20)
                }).buttonStyle(MainButton())
                
                if openURL != "/No File Selected" {//If file is selected, show extra options
                    HStack{
                        Spacer()
                        ScrollView{
                            VStack{
                                Text(data.getDataString(URL: openURL))
                            }.frame(minWidth: metrics.size.width*0.8)
                        }.background(Color.white)
                        Spacer()
                    }
                }
            }.padding(20)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
