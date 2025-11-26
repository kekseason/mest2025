import 'package:flutter/material.dart';
import 'signup_step3.dart'; // Bir sonraki adım

class SignupStep2 extends StatefulWidget {
  final String email;
  final String phone;
  final String password;

  const SignupStep2({
    super.key,
    required this.email,
    required this.phone,
    required this.password,
  });

  @override
  State<SignupStep2> createState() => _SignupStep2State();
}

class _SignupStep2State extends State<SignupStep2> {
  final _nameController = TextEditingController();
  DateTime? _selectedDate;
  String? _selectedCity;
  String? _selectedGender;

  final List<String> cities = ["İstanbul", "Ankara", "İzmir", "Adana", "Antalya", "Bursa", "Gaziantep", "Konya"];

  void _devamEt() {
    if (_nameController.text.isEmpty || _selectedDate == null || _selectedCity == null || _selectedGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen tüm alanları doldurunuz.")));
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SignupStep3(
          email: widget.email,
          phone: widget.phone,
          password: widget.password,
          name: _nameController.text.trim(),
          birthDate: _selectedDate!,
          city: _selectedCity!,
          gender: _selectedGender!,
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)), // En az 18 yaş
      firstDate: DateTime(1950),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: Theme.of(context).colorScheme.primary, // Pembe
              onPrimary: Colors.white,
              surface: const Color(0xFF1C1C1E), // Koyu kutu
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF0D0D11),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.primary), // Buton pembe
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D11),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Geri", style: TextStyle(fontSize: 16)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProgressBar(context, 2),
            const SizedBox(height: 20),

            const Text("Bize kendinden bahset", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text("Eşleşeceğin insanlara senden bahsedebilmemiz için bize kendin hakkında bazı bilgilerle yardımcı ol. Bizimle paylaştığın bilgilerin hangilerinin eşleştiğin insanlarla paylaşılacağını profilinden düzenleyebilirsin.", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 30),

            // Ad
            const Text("Adın", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(hintText: "Adınızı yazınız"),
            ),
            const SizedBox(height: 20),

            // Yaş (Tarih Seçici)
            const Text("Kaç Yaşındasın", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _selectDate(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(16)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _selectedDate == null ? "Tarih seç" : "${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}",
                      style: TextStyle(color: _selectedDate == null ? Colors.grey : Colors.white),
                    ),
                    const Icon(Icons.calendar_today, color: Colors.grey, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Konum (Dropdown)
            const Text("Nerede Yaşıyorsun", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(16)),
              child: DropdownButtonFormField<String>(
                decoration: const InputDecoration(border: InputBorder.none, hintText: "Yaşadığınız yeri seç"),
                dropdownColor: const Color(0xFF1C1C1E),
                value: _selectedCity,
                items: cities.map((city) => DropdownMenuItem(value: city, child: Text(city, style: const TextStyle(color: Colors.white)))).toList(),
                onChanged: (value) => setState(() => _selectedCity = value),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(height: 20),

            // Cinsiyet (Checkbox/Radio)
            const Text("Cinsiyet:", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildGenderOption("Erkek"),
                const SizedBox(width: 30),
                _buildGenderOption("Kadın"),
              ],
            ),
            const SizedBox(height: 40),

            // Devam Butonu
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _devamEt,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text("Devam", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildGenderOption(String gender) {
    bool isSelected = _selectedGender == gender;
    return GestureDetector(
      onTap: () => setState(() => _selectedGender = gender),
      child: Row(
        children: [
          Container(
            width: 20, height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey, width: 2),
              color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
            ),
            child: isSelected ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
          ),
          const SizedBox(width: 8),
          Text(gender, style: TextStyle(color: isSelected ? Colors.white : Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildProgressBar(BuildContext context, int step) {
    return Row(
      children: List.generate(3, (index) {
        bool isActive = index < step;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: index < 2 ? 5 : 0),
            height: 4,
            decoration: BoxDecoration(
              color: isActive ? Theme.of(context).colorScheme.primary : Colors.grey[800],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}