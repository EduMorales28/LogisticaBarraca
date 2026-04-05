import 'dart:typed_data';

import 'package:syncfusion_flutter_pdf/pdf.dart';

class ParsedInvoiceLine {
  final String code;
  final String description;
  final String price;
  final String taxRate;
  final String quantity;
  final String discountPercent;
  final String total;
  final bool pickedUpAtCounter;

  const ParsedInvoiceLine({
    required this.code,
    required this.description,
    required this.price,
    required this.taxRate,
    required this.quantity,
    required this.discountPercent,
    required this.total,
    this.pickedUpAtCounter = false,
  });

  ParsedInvoiceLine copyWith({bool? pickedUpAtCounter}) {
    return ParsedInvoiceLine(
      code: code,
      description: description,
      price: price,
      taxRate: taxRate,
      quantity: quantity,
      discountPercent: discountPercent,
      total: total,
      pickedUpAtCounter: pickedUpAtCounter ?? this.pickedUpAtCounter,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'code': code,
      'description': description,
      'price': price,
      'taxRate': taxRate,
      'quantity': quantity,
      'discountPercent': discountPercent,
      'total': total,
      'pickedUpAtCounter': pickedUpAtCounter,
    };
  }
}

class ParsedInvoiceData {
  final String invoiceNumber;
  final String customerName;
  final List<ParsedInvoiceLine> lines;
  final String taxableAmount;
  final String ivaAmount;
  final String totalAmount;
  final String currency;
  final String rawText;
  final String? sourceFileName;

  const ParsedInvoiceData({
    required this.invoiceNumber,
    required this.customerName,
    required this.lines,
    required this.taxableAmount,
    required this.ivaAmount,
    required this.totalAmount,
    this.currency = '',
    required this.rawText,
    this.sourceFileName,
  });
}

class InvoiceParser {
  static Future<ParsedInvoiceData?> parsePdfBytes(
    Uint8List bytes, {
    String? sourceFileName,
  }) async {
    final document = PdfDocument(inputBytes: bytes);
    try {
        final rawText = PdfTextExtractor(document).extractText();
        final normalized = rawText
          .replaceAll('\r', '')
          .replaceAll('\u00A0', ' ')
          .replaceAll('\u2007', ' ')
          .replaceAll('\u202F', ' ');
      final lines = normalized
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();

      final invoiceNumber = _parseInvoiceNumber(normalized, lines);
      final customerName = _parseCustomerName(lines);
      final items = _parseItems(lines, normalized);
      final totals = _parseTotals(normalized, lines);
      final currency = _parseCurrency(normalized);

      if (invoiceNumber.isEmpty && customerName.isEmpty && items.isEmpty) {
        return null;
      }

      return ParsedInvoiceData(
        invoiceNumber: invoiceNumber,
        customerName: customerName,
        lines: items,
        taxableAmount: totals.$1,
        ivaAmount: totals.$2,
        totalAmount: totals.$3,
        currency: currency,
        rawText: normalized,
        sourceFileName: sourceFileName,
      );
    } finally {
      document.dispose();
    }
  }

  static String _parseInvoiceNumber(String text, List<String> lines) {
    final match = RegExp(r'Nro\s*:?\s*([0-9]{3,})', caseSensitive: false)
            .firstMatch(text) ??
        RegExp(r'factura\s*:?\s*([A-Z0-9-]{3,})', caseSensitive: false)
            .firstMatch(text);
    if (match != null) {
      final raw = match.group(1)?.trim() ?? '';
      return raw.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    }

    for (final line in lines) {
      if (line.toLowerCase().contains('nro')) {
        final number = RegExp(r'([0-9]{3,})').firstMatch(line)?.group(1);
        if (number != null) {
          return number.replaceFirst(RegExp(r'^0+(?=\d)'), '');
        }
      }
    }
    return '';
  }

  static String _parseCustomerName(List<String> lines) {
    final candidates = <int>[];
    for (int i = 0; i < lines.length; i++) {
      final compact = lines[i].replaceAll(' ', '');
      if (RegExp(r'^\d{10,12}$').hasMatch(compact)) {
        candidates.add(i);
      }
    }

    if (candidates.length >= 2) {
      final idx = candidates[1];
      if (idx + 1 < lines.length) {
        return lines[idx + 1];
      }
    }

    for (int i = 0; i < lines.length - 1; i++) {
      if (RegExp(r'^\d{10,12}$').hasMatch(lines[i].replaceAll(' ', ''))) {
        final next = lines[i + 1];
        if (_looksLikeName(next)) return next;
      }
    }

    return '';
  }

  static List<ParsedInvoiceLine> _parseItems(List<String> lines, String fullText) {
    // Primary: el PDF extrae columna por columna. Cada item viene como:
    // descripcion, cant, tasa, codigo, desc%, precio, total
    final columnOrder = _parseItemsColumnOrder(lines);
    if (columnOrder.isNotEmpty) return columnOrder;

    final section = _extractItemsSection(fullText);
    if (section.isNotEmpty) {
      final sequential = _parseItemsFromSequentialRows(section);
      if (sequential.isNotEmpty) return sequential;
    }

    final byColumns = _parseItemsFromColumnBlocks(fullText);
    if (byColumns.isNotEmpty) return byColumns;

    int headerIndex = lines.indexWhere(
      (line) => line.toLowerCase().contains('código') || line.toLowerCase().contains('codigo'),
    );
    if (headerIndex < 0) {
      headerIndex = lines.indexWhere((line) {
        final lower = line.toLowerCase();
        return lower.contains('precio') &&
            (lower.contains('cant') || lower.contains('cantidad'));
      });
    }
    if (headerIndex < 0) {
      headerIndex = -1;
    }

    final parsed = <ParsedInvoiceLine>[];
    for (int i = headerIndex + 1; i < lines.length; i++) {
      final line = lines[i];
      final lower = line.toLowerCase();
      if (lower.contains('adenda') ||
          lower.contains('imponible') ||
          lower.contains('i.v.a') ||
          lower.startsWith('básico') ||
          lower.startsWith('basico') ||
          lower == 'total') {
        if (parsed.isNotEmpty) break;
        continue;
      }

      final parsedLine = _tryParseItemLine(line);
      if (parsedLine != null) {
        parsed.add(parsedLine);
        continue;
      }

      if (i + 1 < lines.length) {
        final combined = '$line ${lines[i + 1]}';
        final combinedParsed = _tryParseItemLine(combined);
        if (combinedParsed != null) {
          parsed.add(combinedParsed);
          i += 1;
          continue;
        }
      }

      if (i + 2 < lines.length) {
        final combinedThree = '$line ${lines[i + 1]} ${lines[i + 2]}';
        final parsedThree = _tryParseItemLine(combinedThree);
        if (parsedThree != null) {
          parsed.add(parsedThree);
          i += 2;
        }
      }
    }

    if (parsed.isNotEmpty) return parsed;

    final fallbackMatches = RegExp(
      r'^(\d{4,})\s+(.+?)\s+([0-9][0-9.,]*)\s+([A-Z])\s+([0-9][0-9.,]*)\s+([0-9][0-9.,]*)\s+([0-9][0-9.,]*)$',
      multiLine: true,
    ).allMatches(fullText);

    final seenCodes = <String>{};
    for (final match in fallbackMatches) {
      final code = match.group(1)?.trim() ?? '';
      if (code.isEmpty || seenCodes.contains(code)) continue;
      seenCodes.add(code);

      parsed.add(
        ParsedInvoiceLine(
          code: code,
          description: match.group(2)?.trim() ?? '',
          price: match.group(3)?.trim() ?? '',
          taxRate: match.group(4)?.trim() ?? '',
          quantity: match.group(5)?.trim() ?? '',
          discountPercent: match.group(6)?.trim() ?? '',
          total: match.group(7)?.trim() ?? '',
        ),
      );
    }

    if (parsed.isNotEmpty) return parsed;

    final globalFallback = RegExp(
      r'(\d{5,})\s+([A-Z0-9ÁÉÍÓÚÑ/().,%\-\s]{3,}?)\s+([0-9][0-9.,]*)\s+([A-Z])\s+([0-9][0-9.,]*)\s+([0-9][0-9.,]*)\s+([0-9][0-9.,]*)',
      caseSensitive: false,
      dotAll: true,
    ).allMatches(fullText);

    final seenGlobal = <String>{};
    for (final match in globalFallback) {
      final code = match.group(1)?.trim() ?? '';
      final description = (match.group(2) ?? '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      final price = match.group(3)?.trim() ?? '';
      final tax = match.group(4)?.trim() ?? '';
      final quantity = match.group(5)?.trim() ?? '';
      final discount = match.group(6)?.trim() ?? '';
      final total = match.group(7)?.trim() ?? '';

      if (!RegExp(r'^\d{5,}$').hasMatch(code)) continue;
      if (description.toLowerCase().contains('rut emisor') ||
          description.toLowerCase().contains('e-factura')) {
        continue;
      }
      if (!RegExp(r'^[0-9][0-9.,]*$').hasMatch(price)) continue;
      if (!RegExp(r'^[A-Z]$').hasMatch(tax)) continue;
      if (!RegExp(r'^[0-9][0-9.,]*$').hasMatch(quantity)) continue;
      if (!RegExp(r'^[0-9][0-9.,]*$').hasMatch(discount)) continue;
      if (!RegExp(r'^[0-9][0-9.,]*$').hasMatch(total)) continue;

      final uniqueKey = '$code|$price|$quantity|$total';
      if (seenGlobal.contains(uniqueKey)) continue;
      seenGlobal.add(uniqueKey);

      parsed.add(
        ParsedInvoiceLine(
          code: code,
          description: description,
          price: price,
          taxRate: tax,
          quantity: quantity,
          discountPercent: discount,
          total: total,
        ),
      );
    }

    return parsed;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Parser column-order: el texto del PDF llega por columnas, no por filas.
  // Patrón por ítem: descripción, cant, tasa_letra, código_5+dígitos,
  //                  desc%, precio, total  (7 valores)
  // ──────────────────────────────────────────────────────────────────────────
  static List<ParsedInvoiceLine> _parseItemsColumnOrder(List<String> lines) {
    // El PDF extrae columnas en este orden de headers:
    // Total, Cant, Tasa, Precio, Código, Descripción, Desc. (%)
    // Los ítems empiezan justo DESPUÉS del último header "Desc. (%)"
    // Cada ítem viene en 7 líneas: Descripción, Cant, Tasa, Código, Disc%, Precio, Total

    // 1. Buscar el último header de columna (Desc. (%))
    int startIdx = -1;
    for (int j = 0; j < lines.length; j++) {
      final lower = lines[j].trim().toLowerCase();
      if (lower.contains('desc') && lower.contains('%')) {
        startIdx = j + 1;
        break;
      }
    }
    if (startIdx < 0) return const [];

    // 2. Leer ítems desde startIdx en grupos de 7
    final parsed = <ParsedInvoiceLine>[];
    int i = startIdx;
    while (i + 6 < lines.length) {
      final desc  = lines[i].trim();
      final qty   = lines[i + 1].trim();
      final tax   = lines[i + 2].trim();
      final code  = lines[i + 3].trim();
      final disc  = lines[i + 4].trim();
      final price = lines[i + 5].trim();
      final total = lines[i + 6].trim();

      // Parar al llegar a sección de totales
      final descLower = desc.toLowerCase();
      if (descLower.contains('imponible') ||
          descLower.contains('i.v.a') ||
          descLower.startsWith('básico') ||
          descLower.startsWith('basico') ||
          descLower.contains('adenda') ||
          descLower == 'total') {
        break;
      }

      if (_isItemDescription(desc) &&
          _isDecimalNum(qty) &&
          _isSingleUpperLetter(tax) &&
          _isLongCode(code) &&
          _isDecimalNum(disc) &&
          _isDecimalNum(price) &&
          _isDecimalNum(total)) {
        parsed.add(ParsedInvoiceLine(
          code: code,
          description: desc,
          price: price,
          taxRate: tax,
          quantity: qty,
          discountPercent: disc,
          total: total,
        ));
        i += 7;
      } else {
        i++; // línea no reconocida, avanzar de a una
      }
    }
    return parsed;
  }

  static bool _isItemDescription(String t) {
    if (t.isEmpty) return false;
    if (RegExp(r'^[\d.,\s]+$').hasMatch(t)) return false; // número puro
    if (RegExp(r'^[A-Z]$').hasMatch(t)) return false;      // letra sola (tasa)
    if (RegExp(r'^\d{4,}$').hasMatch(t)) return false;     // código numérico
    return RegExp(r'[A-Za-z\u00C0-\u017E]').hasMatch(t);  // tiene letras reales
  }

  static bool _isDecimalNum(String s) {
    final t = s.trim();
    return t.isNotEmpty && RegExp(r'^[\d.,]+$').hasMatch(t);
  }

  static bool _isSingleUpperLetter(String s) =>
      RegExp(r'^[A-Z]$').hasMatch(s.trim());

  static bool _isLongCode(String s) =>
      RegExp(r'^\d{5,}$').hasMatch(s.trim());

  static String _extractItemsSection(String fullText) {
    final lower = fullText.toLowerCase();
    final start = lower.contains('código')
        ? lower.indexOf('código')
        : lower.indexOf('codigo');
    if (start < 0) return '';

    int end = lower.length;
    final endMarkers = [
      'adenda',
      'imponible',
      'i.v.a.',
      'i.v.a',
      'básico',
      'basico',
      'total',
    ];
    for (final marker in endMarkers) {
      final idx = lower.indexOf(marker, start + 1);
      if (idx >= 0 && idx < end) {
        end = idx;
      }
    }
    return fullText.substring(start, end);
  }

  static List<ParsedInvoiceLine> _parseItemsFromSequentialRows(String section) {
    final normalized = section.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) return const [];

    final rows = RegExp(
      r'(\d{5,})\s+(.+?)\s+([0-9][0-9.,]*)\s+([A-Z])\s+([0-9][0-9.,]*)\s+([0-9][0-9.,]*)\s+([0-9][0-9.,]*)(?=\s+\d{5,}\s+|$)',
      dotAll: true,
    ).allMatches(normalized);

    final parsed = <ParsedInvoiceLine>[];
    for (final match in rows) {
      final code = match.group(1)?.trim() ?? '';
      final description = (match.group(2) ?? '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      final price = match.group(3)?.trim() ?? '';
      final tax = match.group(4)?.trim() ?? '';
      final quantity = match.group(5)?.trim() ?? '';
      final discount = match.group(6)?.trim() ?? '';
      final total = match.group(7)?.trim() ?? '';

      if (code.isEmpty || description.isEmpty) continue;

      parsed.add(
        ParsedInvoiceLine(
          code: code,
          description: description,
          price: price,
          taxRate: tax,
          quantity: quantity,
          discountPercent: discount,
          total: total,
        ),
      );
    }
    return parsed;
  }

  static List<ParsedInvoiceLine> _parseItemsFromColumnBlocks(String fullText) {
    final tablePattern = RegExp(
      r'c[oó]digo\s+([\s\S]*?)\s+descripci[oó]n\s+([\s\S]*?)\s+precio\s+([\s\S]*?)\s+tasa\s+([\s\S]*?)\s+cant\s+([\s\S]*?)\s+desc\.?\s*\(%\)\s+([\s\S]*?)\s+total\s+([\s\S]*?)(?:adenda|imponible|i\.v\.a\.|b[aá]sico|$)',
      caseSensitive: false,
    );

    final match = tablePattern.firstMatch(fullText);
    if (match == null) return const [];

    List<String> splitColumn(String? raw) =>
        (raw ?? '')
            .split('\n')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();

    final codes = splitColumn(match.group(1));
    final descriptions = splitColumn(match.group(2));
    final prices = splitColumn(match.group(3));
    final taxes = splitColumn(match.group(4));
    final quantities = splitColumn(match.group(5));
    final discounts = splitColumn(match.group(6));
    final totals = splitColumn(match.group(7));

    final rowCount = [
      codes.length,
      descriptions.length,
      prices.length,
      taxes.length,
      quantities.length,
      discounts.length,
      totals.length,
    ].reduce((a, b) => a < b ? a : b);

    if (rowCount <= 0) return const [];

    final parsed = <ParsedInvoiceLine>[];
    final seen = <String>{};
    for (int i = 0; i < rowCount; i++) {
      final code = codes[i];
      final description = descriptions[i];
      final price = prices[i];
      final tax = taxes[i];
      final quantity = quantities[i];
      final discount = discounts[i];
      final total = totals[i];

      if (!RegExp(r'^\d{3,}$').hasMatch(code)) continue;
      if (!RegExp(r'^[0-9][0-9.,]*$').hasMatch(price)) continue;
      if (!RegExp(r'^[A-Z]$').hasMatch(tax)) continue;
      if (!RegExp(r'^[0-9][0-9.,]*$').hasMatch(quantity)) continue;
      if (!RegExp(r'^[0-9][0-9.,]*$').hasMatch(discount)) continue;
      if (!RegExp(r'^[0-9][0-9.,]*$').hasMatch(total)) continue;
      if (description.isEmpty) continue;

      final uniqueKey = '$code|$price|$quantity|$total';
      if (seen.contains(uniqueKey)) continue;
      seen.add(uniqueKey);

      parsed.add(
        ParsedInvoiceLine(
          code: code,
          description: description,
          price: price,
          taxRate: tax,
          quantity: quantity,
          discountPercent: discount,
          total: total,
        ),
      );
    }

    return parsed;
  }

  static ParsedInvoiceLine? _tryParseItemLine(String line) {
    final compactMatch = RegExp(
      r'^(\d{5,})\s+(.+?)\s+([0-9][0-9.,]*)\s+([A-Z])\s+([0-9][0-9.,]*)\s+([0-9][0-9.,]*)\s+([0-9][0-9.,]*)$',
    ).firstMatch(line.trim());
    if (compactMatch != null) {
      return ParsedInvoiceLine(
        code: compactMatch.group(1)?.trim() ?? '',
        description: compactMatch.group(2)?.trim() ?? '',
        price: compactMatch.group(3)?.trim() ?? '',
        taxRate: compactMatch.group(4)?.trim() ?? '',
        quantity: compactMatch.group(5)?.trim() ?? '',
        discountPercent: compactMatch.group(6)?.trim() ?? '',
        total: compactMatch.group(7)?.trim() ?? '',
      );
    }

    final tokens = line.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    if (tokens.length < 7) return null;

    final code = tokens.first;
    if (!RegExp(r'^\d{3,}$').hasMatch(code)) return null;

    final total = tokens[tokens.length - 1];
    final discount = tokens[tokens.length - 2];
    final quantity = tokens[tokens.length - 3];
    final taxRate = tokens[tokens.length - 4];
    final price = tokens[tokens.length - 5];
    final descriptionTokens = tokens.sublist(1, tokens.length - 5);
    final description = descriptionTokens.join(' ').trim();

    final numberPattern = RegExp(r'^[0-9][0-9.,]*$');
    if (!numberPattern.hasMatch(price) ||
        !numberPattern.hasMatch(quantity) ||
        !numberPattern.hasMatch(discount) ||
        !numberPattern.hasMatch(total) ||
        !RegExp(r'^[A-Z]$').hasMatch(taxRate) ||
        description.isEmpty) {
      return null;
    }

    return ParsedInvoiceLine(
      code: code,
      description: description,
      price: price,
      taxRate: taxRate,
      quantity: quantity,
      discountPercent: discount,
      total: total,
    );
  }

  static (String, String, String) _parseTotals(String text, List<String> lines) {
    // En PDFs extraídos por columnas, los valores del cuadro de totales aparecen
    // como líneas sueltas después del label de cada fila:
    //   Mínimo → 4.535,99 (IVA) → 20.618,16 (Imponible)
    //   Total  → 0,00           → 25.154,15 (total general)
    String iva = '';
    String imponible = '';
    String total = '';

    // 1. IVA e Imponible: buscar el primer label de categoría impositiva seguido de 2 números
    for (int i = 0; i < lines.length; i++) {
      final lower = lines[i].trim().toLowerCase();
      if ((lower == 'mínimo' || lower == 'minimo' ||
           lower == 'básico' || lower == 'basico') &&
          i + 2 < lines.length) {
        final a = lines[i + 1].trim();
        final b = lines[i + 2].trim();
        if (_isDecimalNum(a) && _isDecimalNum(b)) {
          iva = a;
          imponible = b;
          break;
        }
      }
    }

    // 2. Total general: buscar "Total" hacia el final seguido de 2 números (tomar el mayor)
    for (int i = lines.length - 1; i >= 0; i--) {
      if (lines[i].trim().toLowerCase() == 'total' && i + 2 < lines.length) {
        final a = lines[i + 1].trim();
        final b = lines[i + 2].trim();
        if (_isDecimalNum(a) && _isDecimalNum(b)) {
          // El mayor de los dos es el total general
          total = b;
          break;
        }
        // Si solo el siguiente es número, usarlo
        if (_isDecimalNum(a)) {
          total = a;
          break;
        }
      }
    }

    // 3. Fallback: regex clásico para Básico en una línea
    if (total.isEmpty) {
      final basicMatch = RegExp(
        r'(?:Básico|Basico)\s+([0-9][0-9.,]*)\s+([0-9][0-9.,]*)\s+([0-9][0-9.,]*)',
        caseSensitive: false,
      ).firstMatch(text);
      if (basicMatch != null) {
        return (
          basicMatch.group(1)?.trim() ?? '',
          basicMatch.group(2)?.trim() ?? '',
          basicMatch.group(3)?.trim() ?? '',
        );
      }
    }

    return (imponible, iva, total);
  }

  static bool _looksLikeName(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return false;
    if (trimmed.contains('@')) return false;
    if (trimmed.toLowerCase().contains('barraca')) return false;
    return RegExp(r'^[A-ZÁÉÍÓÚÑ0-9 .-]{4,}$').hasMatch(trimmed);
  }

  static String _parseCurrency(String text) {
    // Busca patrones comunes de moneda en facturas uruguayas
    final patterns = [
      RegExp(r'moneda\s*:?\s*(PESOS URUGUAYOS|DÓLARES|DOLARES|USD|UYU|U\$S|\$U)', caseSensitive: false),
      RegExp(r'(PESOS URUGUAYOS|DÓLARES AMERICANOS|DÓLARES|DOLARES AMERICANOS|DOLARES)', caseSensitive: false),
      RegExp(r'\b(USD|UYU|U\$S|\$U)\b'),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final raw = (match.groupCount >= 1 ? match.group(1) : match.group(0)) ?? '';
        final upper = raw.trim().toUpperCase();
        if (upper.contains('PESO')) return 'Pesos uruguayos (\$)';
        if (upper.contains('DÓLAR') || upper.contains('DOLAR') || upper == 'USD') return 'Dólares (USD)';
        if (upper == 'UYU') return 'Pesos uruguayos (\$)';
        if (upper == 'U\$S' || upper == '\$U') return 'Dólares (U\$S)';
        return raw.trim();
      }
    }
    return '';
  }
}
