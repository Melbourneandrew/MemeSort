
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:imagepickerflutter/GalleryImage.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_ml_vision/firebase_ml_vision.dart';
import 'package:path_provider/path_provider.dart';
import 'detector_painter.dart';


class MultiGallerySelectPage extends StatefulWidget{
  createState() => _MultiGallerySelectPageState();
}

class _MultiGallerySelectPageState extends State<MultiGallerySelectPage> with WidgetsBindingObserver{
  final _channel = MethodChannel("/gallery");

  var _selectedItems = List<GalleryImage>();
  var _itemCache = Map<int, GalleryImage>();
  var _memeCache = Map<int, GalleryImage>();
  var _resultsCache = Map<int, dynamic>();

  final TextRecognizer _textRecognizer = FirebaseVision.instance.textRecognizer();

  _selectItem(int index) async {
    var galleryImage = await _getItem(index, false);

    setState(() {
      if (_isSelected(galleryImage.id)) {
        _selectedItems.removeWhere((anItem) => anItem.id == galleryImage.id);
      } else {
        _selectedItems.add(galleryImage);
      }
    });
  }

  _isSelected(String id) {
    return _selectedItems.where((item) => item.id == id).length > 0;
  }

  var _numberOfItems = 0;
  List<Color> shadowColors = new List(4);

  //Must be in the main widget so it can be invoked by didChangeAppLifecycleState
  void getColors(){
    List<Color> colorPool = [Colors.red, Colors.green, Colors.blue, Colors.purple, Colors.pinkAccent, Colors.amber, Colors.cyanAccent, Colors.deepOrange];
    Random rand = new Random();
    int rand1, rand2, rand3, rand4;
    rand1 = rand.nextInt(7);
    rand2 = rand.nextInt(7);
    rand3 = rand.nextInt(7);
    rand4 = rand.nextInt(7);
    while(rand2 == rand1){
      rand2 == rand.nextInt(7);
    }
    rand3 = rand.nextInt(7);
    while(rand3 == rand2 || rand3 == rand1){
      rand3 = rand.nextInt(7);
    }
    rand4 = rand.nextInt(7);
    while(rand4 == rand3 || rand4 == rand2 || rand4 == rand1){
      rand4 = rand.nextInt(7);
    }
    shadowColors[0] = colorPool[rand1];
    shadowColors[1] = colorPool[rand2];
    shadowColors[2] = colorPool[rand3];
    shadowColors[3] = colorPool[rand4];
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _channel.invokeMethod<int>("getItemCount").then((count) => setState(() {
      _numberOfItems = count;
    }));

    getColors();

  }
  @override
  void dispose(){
    WidgetsBinding.instance.removeObserver(this);
    _textRecognizer.close();
    super.dispose();
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state){
    super.didChangeAppLifecycleState(state);
    if(state == AppLifecycleState.resumed){
      setState(() {
        getColors();
      });
    }
  }

  Future<GalleryImage> _getItem(int index, bool meme) async {
    //bool meme determines if entire cameraroll is returned, or if just the memes get sent back
    if (!meme && _itemCache[index] != null && _itemCache[index].meme == false) {
      return _itemCache[index];
    } else if(meme && _itemCache[index] != null && _itemCache[index].meme == true){
      return _itemCache[index];
    } else {
      // Method Channels get gallery images
      var channelResponse = await _channel.invokeMethod("getItem", index);
      var item = Map<String, dynamic>.from(channelResponse);

      var galleryImage = GalleryImage(
          bytes: item['data'],
          id: item['id'],
          dateCreated: item['created'],
          location: item['location'],
          meme: false);

      _itemCache[index] = galleryImage;

      dynamic scan = _scanImage(galleryImage, index);
      galleryImage.scanned = true;

      if(scan != null){
        galleryImage.scanResults = scan;
        galleryImage.meme = true;
      }

      return galleryImage;
    }
  }

  Future<Size> _getImageSize(GalleryImage item) async {
    final Completer<Size> completer = Completer<Size>();

    final Image image = Image.memory(item.bytes);
    image.image.resolve(const ImageConfiguration()).addListener(
      ImageStreamListener((ImageInfo info, bool _) {
        completer.complete(Size(
          info.image.width.toDouble(),
          info.image.height.toDouble(),
        ));
      }),
    );

    final Size imageSize = await completer.future;
    return imageSize;
  }

  Future<dynamic> _scanImage(GalleryImage item,int indx) async{
      Directory cache = await getTemporaryDirectory();
      var path = cache.path;

      File img = new File("$path/img$indx.png");
      await img.writeAsBytes(item.bytes);

      final FirebaseVisionImage visionImage = FirebaseVisionImage.fromFile(img);

      dynamic results;
      results = await _textRecognizer.processImage(visionImage);

      //print("Result Text: " + results.text + "\n");
      return results;
  }

//  Future<Size> _getPickedImageSize(File item) async {
//    final Completer<Size> completer = Completer<Size>();
//
//    final Image image = Image.file(item);
//
//    image.image.resolve(const ImageConfiguration()).addListener(
//      ImageStreamListener((ImageInfo info, bool _) {
//        completer.complete(Size(
//          info.image.width.toDouble(),
//          info.image.height.toDouble(),
//        ));
//      }),
//    );
//
//    final Size imageSize = await completer.future;
//    return imageSize;
//  }
//
//  Future<dynamic> _pickAndScan() async{
//    final File imageFile = await ImagePicker.pickImage(source: ImageSource.gallery);
//
//    if (imageFile != null) {
//      var size = await _getPickedImageSize(imageFile);
//
//      final FirebaseVisionImage visionImage =
//      FirebaseVisionImage.fromFile(imageFile);
//
//      dynamic results;
//      results = await _textRecognizer.processImage(visionImage);
//
//      CustomPainter painter;
//      painter = TextDetectorPainter(size, results);
//
////      CustomPaint paint = CustomPaint(painter: painter);
//
//      showDialog(context: context,
//        builder: (BuildContext context){
//          return AlertDialog(
//            title: Text("Scan results"),
//            content: Container(
//               constraints: const BoxConstraints.expand(),
//                decoration: BoxDecoration(
//                image: DecorationImage(
//                    image: Image.file(imageFile).image,
//                    fit: BoxFit.fill
//                ),
//              ),
//                child: size == null || results == null
//                    ? const Center(
//                  child: Text(
//                    'Scanning...',
//                    style: TextStyle(
//                      color: Colors.green,
//                      fontSize: 30.0,
//                    ),
//                  ),
//                )
//                    : CustomPaint(painter: painter),
//            )
//          );
//      }
//      );
//    }
//  }

  _buildItem(int index) => GestureDetector(
      onTap: ()  {
        Future<GalleryImage> _image = _getItem(index, false);
        showDialog(context: context,
        builder: (BuildContext context){
          return AlertDialog(
            title: Text("Photo"),
            content:FutureBuilder(
                future: _getItem(index, false),
                builder: (context, snapshot) {
                  var item = snapshot?.data;
                  if (item != null) {
                    return Container(
                      child: Image.memory(item.bytes, fit: BoxFit.cover),
                      decoration: BoxDecoration(
                          border: Border.all(
                              color: Theme.of(context).primaryColor,
                              width: 2,
                              style: _isSelected(item.id)
                                  ? BorderStyle.solid
                                  : BorderStyle.none)),
                    );
                  }
                  return Container();
                }),
          );
        }
        );
      },
      child: Card(
        elevation: 2.0,
        child: FutureBuilder(
            future: _getItem(index, false),
            builder: (context, snapshot) {
              var item = snapshot?.data;
              if (item != null) {
                return Container(
                  child: Image.memory(item.bytes, fit: BoxFit.cover),
                  decoration: BoxDecoration(
                      border: Border.all(
                          color: Theme.of(context).primaryColor,
                          width: 2,
                          style: _isSelected(item.id)
                              ? BorderStyle.solid
                              : BorderStyle.none)),
                );
              }
              return Container();
            }),
      ));

  _buildMeme(int index) => GestureDetector(
      onTap: () {
        _selectItem(index);
      },
      child: Card(
        elevation: 2.0,
        child: FutureBuilder(
            future: _getItem(index,true),
            builder: (context, snapshot) {
              var item = snapshot?.data;
              if (item != null) {
                return Container(
                  child: Image.memory(item.bytes, fit: BoxFit.cover),
                  decoration: BoxDecoration(
                      border: Border.all(
                          color: Theme.of(context).primaryColor,
                          width: 2,
                          style: _isSelected(item.id)
                              ? BorderStyle.solid
                              : BorderStyle.none)),
                );
              }
              return Container();
            }),
      ));

  @override
  Widget build(BuildContext context) {
    return Center(
        child:Container(
          color: Colors.white,
          height: double.infinity,
          width: double.infinity,
          padding: EdgeInsets.all(30),
          child:Column(
            children: <Widget>[
              MemeTitle(title:"Non-Memes", shadowColor1:shadowColors[0], shadowColor2:shadowColors[1]),
              Padding(
                padding: EdgeInsets.only(top:10.0),
                child:SizedBox(
                height: MediaQuery.of(context).size.height/3, // fixed height
                child: GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3),
                    itemCount: _numberOfItems,
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (context, index) {
                      print("About to call build item \n");
                      return _buildItem(index);
                    }),
              ),
              ),

              MemeTitle(title:"Memes", shadowColor1:shadowColors[2], shadowColor2:shadowColors[3]),
              Padding(
                padding: EdgeInsets.only(top:10.0),
                child: SizedBox(
                height: MediaQuery.of(context).size.height/3, // fixed height
                child: GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3),
                    itemCount: _numberOfItems,
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (context, index) {
                      return _buildMeme(index);
                    }),
                ),
              ),
//              Container(
//                child: OutlineButton(
//                  child: Text("Pick Image"),
//                  onPressed: _pickAndScan),
//
//              ),
            ],
          ),
        )
    );
  }
}
class MemeTitle extends StatelessWidget{
  MemeTitle({this.title, this.shadowColor1, this.shadowColor2});
  final String title;
  final Color shadowColor1, shadowColor2;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        type: MaterialType.card,
        child:Text(title,
          textAlign: TextAlign.left,
          style:TextStyle(fontSize: 30.0, fontWeight: FontWeight.bold, color: Colors.black,
            shadows: [
              Shadow(
                color: shadowColor1,
                blurRadius: 5.0,
                offset: Offset(-10, 5.0),
              ),
              Shadow(
                color: shadowColor2,
                blurRadius: 5.0,
                offset: Offset(5.0, -10.0),
              ),
            ],
          ),
        ),
      ),
    );
  }
}