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
    //Storage for markers
    var markers:[marker] = []
    
    //Needed Project File Information
    var projectName:String = "No Project Selected"
    var frameRate: Double = 0
    
    struct marker {
        var hours:Int = 0
        var minutes:Int = 0
        var seconds:Int = 0
        var frames:Int = 0
        var name:String = ""
        let id = UUID()
    }
    
    //A lot of the logic for this function came from here
    //http://www.andrewduncan.net/timecodes/
    
    func dropFrameMath(inFrames: Int, inRate: Double) -> (Int, Int, Int, Int){
        let rawFrames = inFrames
        let roundedFrameRate = Int(inRate.rounded())
        var finalFrames: Double
        if inRate != inRate.rounded() {
            
            let tenMins = Int(rawFrames / (600 * roundedFrameRate))
            let mins = Int(rawFrames / (60 * roundedFrameRate))
            
            let addedFrames = (2 * mins) + (-2 * tenMins)
            
             finalFrames = Double(rawFrames + addedFrames)
        } else {
             finalFrames = Double(rawFrames)
        }
        
        let hours = Int((((finalFrames / Double(roundedFrameRate)) / 60) / 60).truncatingRemainder(dividingBy: 60))
        let minutes = Int(( (finalFrames / Double(roundedFrameRate)) / 60).truncatingRemainder(dividingBy: 60))
        let seconds = Int((finalFrames / Double(roundedFrameRate)).truncatingRemainder(dividingBy: 60))
        let frames = Int(finalFrames.truncatingRemainder(dividingBy: Double(roundedFrameRate)))
        
        return (hours,minutes,seconds,frames)
        
    }

    
    func divideNums(input: String) -> Double {
        if input == "0" {
            return 0
        }
        var firstNumStr = input[...input.firstIndex(of: "/")!]
        var secondNumStr = input[input.firstIndex(of: "/")!...]
        firstNumStr.removeLast()
        secondNumStr.removeFirst()
        if let firstNum = Double(firstNumStr), let secondNum = Double(secondNumStr) {
            return firstNum/secondNum
        } else {
            return -1
        }
    }

    //Here's What I need
    //Overall Framerate
    //Project Name
    //
    
    func openFile(URL: String) -> Bool {
        //Empty Marker Array so that we start fresh
        markers = []
        //Try to open the file
        if let contents = try? String(contentsOfFile: String(URL.dropFirst(7))) {
            //Load Project Name
            if let range = contents.range(of: "project name=\"") {
                projectName = String(contents[range.upperBound...contents.index(contents[contents.index(range.upperBound, offsetBy: 1)...].range(of: "\" uid=\"")!.lowerBound, offsetBy: -1)])
            }
            //FRAME RATE
            if let range = contents.range(of: "frameDuration") {
                let index = contents.index(range.upperBound, offsetBy: 2)
                var temp = contents[index...contents[index...].firstIndex(of: "\"")!]
                temp.removeLast(2)
                frameRate = (Double(round(1000*(1/(divideNums(input: (String(temp))))))/1000))
                var current = contents[index...]
                //START VALUE
                if let range2 = contents.range(of: "<spine>") {
                    current = contents[range2.upperBound...]
                }
                if let range3 = current.range(of: " start=\"") {
                    var temp = contents[range3.upperBound...contents[range3.upperBound...].firstIndex(of: "\"")!]
                    temp.removeLast(2)
                    current = current[range3.upperBound...]
                }
                //At This Point, We have the FPS and Project Name. Awesome.
                
                //BEGIN MARKERS
                while current.contains("<marker start=\""){
                    if let markerRange = current.range(of: "<marker start=\"") {
                        
                        //Get the Reference Clip information needed for the calculation
                        let refClipRange = current[...markerRange.lowerBound].range(of:"<ref-clip name=\"",  options: String.CompareOptions.backwards)
                        let offsetRange = current[refClipRange!.upperBound...markerRange.upperBound].range(of:"offset=\"")
                        let startRange = current[refClipRange!.upperBound...markerRange.upperBound].range(of:"start=\"")
                        let offset = current[offsetRange!.upperBound...current.index(current[offsetRange!.upperBound...].firstIndex(of: "\"")!, offsetBy: -2)]
                        let start = current[startRange!.upperBound...current.index(current[startRange!.upperBound...].firstIndex(of: "\"")!, offsetBy: -2)]
                        
                        
                        //Get the information needed for the marker point calculation.
                        let endIndex = current.index(current[markerRange.upperBound...].firstIndex(of: "\"")!, offsetBy: -2)
                        let markerPoint = current[markerRange.upperBound...endIndex]
                        
                        //Get the marker name
                        let valueRange = current[markerRange.upperBound...].range(of:"value=\"")
                        let endValue = current.index(current[valueRange!.upperBound...].range(of: "\"/>")!.lowerBound, offsetBy: -1)
                        let value = current[valueRange!.upperBound...endValue]
                        
                        //We have all the information we need. Lets convert these to timecodes.
                        
                        //divide the numbers and do the drop frame math
                        //Calculate raw number
                        let rawTimeCode = (divideNums(input: String(markerPoint)) - divideNums(input: String(start))) + divideNums(input: String(offset))
                        var rawFrames = (rawTimeCode * frameRate)
                        rawFrames.round()
                        let (hours, mins, seconds, frames) = dropFrameMath(inFrames:Int(rawFrames), inRate: frameRate)
                        
                        var tempMarker = marker()
                        tempMarker.hours = hours
                        tempMarker.minutes = mins
                        tempMarker.seconds = seconds
                        tempMarker.frames = frames
                        tempMarker.name = String(value)
                        
                        markers.append(tempMarker)
                        //reset string for next iteration
                        current = current[endValue...]
                    }
                }
            } else {
                return false
            }
            return true
        } else {
            return false
        }
    }
    func getDataString(URL: String) -> String {

        var storage = ""
        if data.openFile(URL: URL) {
            for marker in markers {
                storage += "\(marker.minutes):\(marker.seconds):\(marker.frames) - \(marker.name)\n"
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
                openURL = fileUrl.absoluteString.removingPercentEncoding!
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
                Text("No File Selected")
                Button(action: {
                    openFile()
                }, label: {
                    Text("Select File")
                        .padding(.top, 10)
                        .padding(.bottom, 10)
                        .padding(.leading, 20)
                        .padding(.trailing, 20)
                }).buttonStyle(MainButton())
                
                if data.openFile(URL: openURL) {//If file is selected, show extra options
                    VStack{
                        VStack{
                            Text("Project Name:")
                            Text(data.projectName)
                        }
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
