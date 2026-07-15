import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/marketplace_item.dart';
import '../widgets/marketplace/auto_carousel.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/common/score_badge.dart';
import '../services/supabase_service.dart';

class MarketItemDetailScreen extends StatefulWidget {
  final MarketplaceItem item;

  const MarketItemDetailScreen({super.key, required this.item});

  @override
  State<MarketItemDetailScreen> createState() => _MarketItemDetailScreenState();
}

class _MarketItemDetailScreenState extends State<MarketItemDetailScreen> {
  final _offerController = TextEditingController();
  bool _isSendingContact = false;

  Future<bool> _sendToSeller({
    required String type,
    required String message,
    double? offerAmount,
  }) async {
    var sellerId = widget.item.sellerUserId;
    sellerId ??= await SupabaseService.instance.resolveMarketplaceSeller(
      localId: widget.item.id,
      title: widget.item.title,
      price: widget.item.price,
      sourceAnimalId: widget.item.sourceAnimalId,
    );
    if (sellerId == null || sellerId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se encontró un vendedor real para esta publicación. Actualiza el Marketplace e inténtalo nuevamente.',
            ),
          ),
        );
      }
      return false;
    }
    if (message.trim().isEmpty) return false;

    setState(() => _isSendingContact = true);
    try {
      await SupabaseService.instance.sendMarketplaceNotification(
        recipientUserId: sellerId,
        marketplaceLocalId: widget.item.id,
        listingTitle: widget.item.title,
        type: type,
        message: message,
        offerAmount: offerAmount,
      );
      return true;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo contactar al vendedor: $error'),
            backgroundColor: AppColors.alertRed,
          ),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _isSendingContact = false);
    }
  }

  @override
  void dispose() {
    _offerController.dispose();
    super.dispose();
  }

  // Simulación de envío de mensaje por chat
  void _showContactDialog() {
    final messageController = TextEditingController(
      text:
          "Hola, estoy interesado en '${widget.item.title}'. ¿Sigue disponible?",
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Enviar Mensaje al Vendedor', style: AppTextStyles.h2),
                  IconButton(
                    icon: const Icon(LucideIcons.x),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Tiempo prom. de respuesta: ${widget.item.responseTime}',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.primaryGreen,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: messageController,
                maxLines: 4,
                style: AppTextStyles.bodyBold,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.primaryGreen,
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isSendingContact
                      ? null
                      : () async {
                          final sent = await _sendToSeller(
                            type: 'message',
                            message: messageController.text,
                          );
                          if (!sent || !context.mounted) return;
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Mensaje enviado con éxito por Chat',
                                style: AppTextStyles.bodyBold.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                              backgroundColor: AppColors.primaryGreen,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          );
                        },
                  icon: const Icon(LucideIcons.send, color: Colors.white),
                  label: Text(
                    'Enviar Mensaje',
                    style: AppTextStyles.bodyBold.copyWith(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Simulación de hacer una oferta
  void _showOfferDialog() {
    _offerController.text = widget.item.price.toStringAsFixed(0);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              const Icon(LucideIcons.coins, color: AppColors.primaryGreen),
              const SizedBox(width: 8),
              Text('Hacer una Oferta', style: AppTextStyles.h2),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Precio original: \$${widget.item.price.toStringAsFixed(0)}',
                style: AppTextStyles.body,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _offerController,
                keyboardType: TextInputType.number,
                style: AppTextStyles.h2.copyWith(
                  color: AppColors.primaryGreenDark,
                ),
                decoration: InputDecoration(
                  prefixText: '\$ ',
                  labelText: 'Tu Oferta',
                  labelStyle: AppTextStyles.caption,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.primaryGreen,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancelar',
                style: AppTextStyles.body.copyWith(color: AppColors.alertRed),
              ),
            ),
            ElevatedButton(
              onPressed: _isSendingContact
                  ? null
                  : () async {
                      final amount = double.tryParse(_offerController.text);
                      if (amount == null || amount <= 0) return;
                      final sent = await _sendToSeller(
                        type: 'offer',
                        message:
                            'Oferta de \$${amount.toStringAsFixed(2)} por ${widget.item.title}',
                        offerAmount: amount,
                      );
                      if (!sent || !context.mounted) return;
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Oferta de \$${_offerController.text} enviada al vendedor',
                            style: AppTextStyles.bodyBold.copyWith(
                              color: Colors.white,
                            ),
                          ),
                          backgroundColor: AppColors.primaryGreen,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'Enviar Oferta',
                style: AppTextStyles.bodyBold.copyWith(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _certDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: AppTextStyles.caption.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Certificado de Agrocalidad
  void _showCertificate() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF4F6F4),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Cabecera Oficial
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Image.network(
                      'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcR6sFjW4jX4d9y2bWv2X6uH_aG0fX-P_d3g2Q&s',
                      height: 40,
                      errorBuilder: (context, error, stackTrace) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreenDark,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'AGROCALIDAD',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.x),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Título
                Text(
                  'CERTIFICADO ZOOSANITARIO DE MOVILIZACIÓN',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.h3.copyWith(
                    color: AppColors.primaryGreenDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Certificado de Trazabilidad y Buen Producto',
                  style: AppTextStyles.caption.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 20),

                // Contenido del certificado (diseño oficial)
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFC2D6C2),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Estatus
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Código: AGR-2026-908234-EC',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.greenSurface,
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(color: AppColors.primaryGreen),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  LucideIcons.checkCircle,
                                  size: 12,
                                  color: AppColors.primaryGreen,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'APROBADO',
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.primaryGreen,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24, color: AppColors.border),

                      // Detalles del Producto / Animal
                      _certDetail('Producto:', widget.item.title),
                      _certDetail('Categoría:', widget.item.category),
                      _certDetail('Ubicación:', widget.item.location),
                      _certDetail(
                        'Predio de Origen:',
                        'Finca El Milagro (Hato Registrado #0129)',
                      ),
                      _certDetail(
                        'Fiebre Aftosa:',
                        'Predio vacunado y certificado libre de aftosa',
                      ),
                      _certDetail(
                        'Brucelosis & TB:',
                        'Negativo en pruebas semestrales',
                      ),
                      _certDetail('Fecha Emisión:', '10 Ene 2026'),
                      _certDetail('Vencimiento:', '10 Ene 2027'),

                      const Divider(height: 24, color: AppColors.border),

                      // QR & Sello digital
                      Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            color: Colors.grey[200],
                            alignment: Alignment.center,
                            child: const Icon(
                              LucideIcons.qrCode,
                              size: 40,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Verificado por Agrocalidad',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    color: AppColors.primaryGreenDark,
                                  ),
                                ),
                                Text(
                                  'Este producto cumple con los protocolos de trazabilidad agropecuaria y sanidad animal.',
                                  style: AppTextStyles.caption.copyWith(
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Botón cerrar
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryGreenDark,
                      side: const BorderSide(color: AppColors.primaryGreen),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Entendido',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final priceLabel = widget.item.category == 'Leche'
        ? '\$${widget.item.price.toStringAsFixed(2)}/litro'
        : (widget.item.category == 'Queso'
              ? '\$${widget.item.price.toStringAsFixed(1)}/lb'
              : '\$${widget.item.price.toStringAsFixed(0)}');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Detalle del Producto',
          style: AppTextStyles.h2.copyWith(color: AppColors.textPrimary),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          // Imagen del item (Carrusel con zoom)
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.40,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Stack(
                children: [
                  AutoCarousel(
                    imagePaths: widget.item.imagePaths,
                    height: MediaQuery.of(context).size.height * 0.40,
                    isZoomable: true,
                    category: widget.item.category,
                  ),
                  Positioned(
                    top: 14,
                    left: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreenDark,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.item.category,
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 14,
                    right: 14,
                    child: ScoreBadge(score: widget.item.score, size: 48),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Título y Precio
          Text(widget.item.title, style: AppTextStyles.h1),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                priceLabel,
                style: AppTextStyles.h1.copyWith(
                  color: AppColors.primaryGreenDark,
                  fontSize: 28,
                ),
              ),
              if (widget.item.referencePrice != null) ...[
                const SizedBox(width: 10),
                Text(
                  '\$${widget.item.referencePrice!.toStringAsFixed(0)}',
                  style: AppTextStyles.body.copyWith(
                    decoration: TextDecoration.lineThrough,
                    fontSize: 16,
                  ),
                ),
              ],
              const Spacer(),
              if (widget.item.negotiable)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.alertOrangeSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.alertOrange),
                  ),
                  child: Text(
                    'Negociable',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.alertOrange,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),

          // Descripción de la publicación
          if (widget.item.description.isNotEmpty) ...[
            Text('Descripción', style: AppTextStyles.h3),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(widget.item.description, style: AppTextStyles.body),
            ),
            const SizedBox(height: 18),
          ],

          // Certificado de Agrocalidad
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      LucideIcons.shieldCheck,
                      color: AppColors.primaryGreen,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Text('Trazabilidad Agrocalidad', style: AppTextStyles.h3),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Este lote o animal cuenta con un Certificado Zoosanitario de Movilización emitido por Agrocalidad, garantizando la trazabilidad desde su finca de origen.',
                  style: AppTextStyles.body,
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _showCertificate,
                    icon: const Icon(
                      LucideIcons.fileText,
                      size: 18,
                      color: Colors.white,
                    ),
                    label: Text(
                      'Ver Certificado Oficial',
                      style: AppTextStyles.bodyBold.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreenDark,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Detalles Técnicos
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ficha Técnica', style: AppTextStyles.h3),
                const SizedBox(height: 12),
                if (widget.item.weight != null)
                  _techRow(
                    LucideIcons.scale,
                    'Peso Corporal',
                    widget.item.weight!,
                  ),
                if (widget.item.production != null)
                  _techRow(
                    LucideIcons.milk,
                    'Producción Diaria',
                    widget.item.production!,
                  ),
                _techRow(LucideIcons.mapPin, 'Ubicación', widget.item.location),
                _techRow(
                  LucideIcons.clock,
                  'Tiempo de Respuesta',
                  widget.item.responseTime,
                ),
                _techRow(LucideIcons.award, 'Reputación', widget.item.badge),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Análisis de Precio IA
          if (widget.item.priceRange != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.greenSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primaryGreen.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        LucideIcons.brain,
                        color: AppColors.primaryGreenDark,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Análisis de Precio IA',
                        style: AppTextStyles.h3.copyWith(
                          color: AppColors.primaryGreenDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Nuestra Inteligencia Artificial estima que el valor de este producto está dentro del rango óptimo de mercado para la zona de ${widget.item.location.split(',')[0]} (${widget.item.priceRange}). Es una transacción recomendada.',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.primaryGreenDark,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Acciones de contacto
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: _showOfferDialog,
                    icon: const Icon(
                      LucideIcons.coins,
                      color: AppColors.primaryGreenDark,
                    ),
                    label: Text(
                      'Ofertar',
                      style: AppTextStyles.bodyBold.copyWith(
                        color: AppColors.primaryGreenDark,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primaryGreen),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _showContactDialog,
                    icon: const Icon(
                      LucideIcons.messageSquare,
                      color: Colors.white,
                    ),
                    label: Text(
                      'Contactar',
                      style: AppTextStyles.bodyBold.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _techRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Text(label, style: AppTextStyles.body),
          const Spacer(),
          Text(value, style: AppTextStyles.bodyBold),
        ],
      ),
    );
  }
}
