import 'package:flutter/material.dart';

class AuthButton extends StatelessWidget {
  final String text;
  final void Function()?
      onPressed; // Changed from VoidCallback to void Function()?
  final bool isLoading;
  final bool isOutlined;

  const AuthButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final buttonHeight = MediaQuery.of(context).size.height * 0.06;

    final Widget button = isOutlined
        ? OutlinedButton(
            onPressed: isLoading ? () {} : onPressed,
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(
                vertical: buttonHeight * 0.3,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _buildButtonContent(),
          )
        : ElevatedButton(
            onPressed: isLoading ? () {} : onPressed,
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(
                vertical: buttonHeight * 0.3,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _buildButtonContent(),
          );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: SizedBox(
        height: buttonHeight,
        width: double.infinity,
        child: button,
      ),
    );
  }

  Widget _buildButtonContent() {
    return isLoading
        ? const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
            ),
          )
        : Text(text);
  }
}
