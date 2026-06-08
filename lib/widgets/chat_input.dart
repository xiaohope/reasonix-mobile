import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ChatInput extends StatefulWidget {
  final Function(String) onSend;
  final Function({String? text, File? image})? onSendWithImage;
  final bool enabled;
  const ChatInput({super.key, required this.onSend, this.onSendWithImage, this.enabled = true});
  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _picker = ImagePicker();
  File? _pickedImage;

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty && _pickedImage == null) return;
    if (widget.onSendWithImage != null) {
      widget.onSendWithImage!(text: text.isEmpty ? null : text, image: _pickedImage);
    } else {
      widget.onSend(text);
    }
    _controller.clear();
    _pickedImage = null;
    _focusNode.requestFocus();
    setState(() {});
  }

  Future<void> _pickImage() async {
    final file = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1024);
    if (file != null) {
      setState(() => _pickedImage = File(file.path));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.1))),
      ),
      child: SafeArea(top: false, child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_pickedImage != null)
            Container(
              margin: const EdgeInsets.only(bottom: 4),
              height: 80, width: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                image: DecorationImage(image: FileImage(_pickedImage!), fit: BoxFit.cover),
              ),
              child: Align(
                alignment: Alignment.topRight,
                child: GestureDetector(
                  onTap: () => setState(() => _pickedImage = null),
                  child: const Icon(Icons.close, size: 18, color: Colors.white),
                ),
              ),
            ),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            IconButton(
              onPressed: widget.enabled ? _pickImage : null,
              icon: const Icon(Icons.image_outlined),
              tooltip: '上传图片',
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            Expanded(child: TextField(
              controller: _controller, focusNode: _focusNode,
              enabled: widget.enabled, maxLines: 5, minLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: widget.enabled ? (_) => _send() : null,
              decoration: InputDecoration(
                hintText: widget.enabled ? '给 Reasonix 下指令...' : '等待回复...',
                hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: InputBorder.none, filled: false,
              ),
              style: Theme.of(context).textTheme.bodyMedium,
            )),
            const SizedBox(width: 4),
            IconButton(
              onPressed: widget.enabled ? _send : null,
              icon: Icon(Icons.send_rounded, color: widget.enabled ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
              tooltip: '发送',
            ),
          ]),
        ],
      )),
    );
  }
}
