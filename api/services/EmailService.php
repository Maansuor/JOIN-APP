<?php

/**
 * Servicio de Envío de Correos para Join
 * 
 * Este servicio centraliza el envío de emails de la aplicación (Magic Codes, Notificaciones).
 * Para un uso profesional, se recomienda integrar PHPMailer o una API como SendGrid.
 */
class EmailService {
    
    // --- CONFIGURACIÓN SMTP (Completar con tus datos reales) ---
    private const SMTP_HOST = 'smtp.gmail.com'; 
    private const SMTP_USER = 'tu-email-real@gmail.com'; // <--- CAMBIA ESTO
    private const SMTP_PASS = 'tu-password-de-aplicacion'; // <--- CAMBIA ESTO
    private const SMTP_PORT = 587;
    // --------------------------------------------------------

    /**
     * Envía un Magic Code al usuario
     */
    public static function sendMagicCode(string $email, string $code): bool {
        $subject = "$code es tu codigo de acceso a Join";
        $template = self::getMagicCodeTemplate($code);
        
        return self::send($email, $subject, $template);
    }

    /**
     * Motor de envío
     */
    private static function send(string $to, string $subject, string $htmlContent): bool {
        // Log local para desarrollo (siempre se guarda una copia por si falla el envío)
        $logPath = dirname(__DIR__) . '/mail_log.txt';
        $logEntry = date('[Y-m-d H:i:s]') . " [MAIL] Para $to: $subject | Codigo: " . strip_tags($htmlContent) . "\n";
        file_put_contents($logPath, $logEntry, FILE_APPEND);

        // Cabeceras para HTML
        $headers = "MIME-Version: 1.0" . "\r\n";
        $headers .= "Content-type:text/html;charset=UTF-8" . "\r\n";
        $headers .= 'From: Join App <no-reply@joinapp.com>' . "\r\n";

        /**
         * NOTA PROFESIONAL:
         * Para que mail() funcione en localhost (XAMPP), debes tener configurado sendmail.
         * Si quieres usar PHPMailer con los datos SMTP de arriba, descarga la librería 
         * y reemplaza este método. Por ahora, habilitamos mail() estándar.
         */
        
        try {
            // Habilitamos el envío real vía PHP mail()
            return @mail($to, $subject, $htmlContent, $headers);
        } catch (Exception $e) {
            error_log("Error enviando email: " . $e->getMessage());
            return false;
        }
    }

    /**
     * Plantilla HTML profesional para el Magic Code
     */
    private static function getMagicCodeTemplate(string $code): string {
        return "
        <div style='font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #eeeeee; border-radius: 12px;'>
            <div style='text-align: center; margin-bottom: 30px;'>
                <h1 style='color: #FD7C36; margin: 0;'>Join</h1>
                <p style='color: #666666;'>Tu entrada al mundo de los planes</p>
            </div>
            
            <div style='background-color: #f9f9f9; padding: 30px; border-radius: 10px; text-align: center;'>
                <p style='font-size: 16px; color: #333333;'>Hola,</p>
                <p style='font-size: 16px; color: #333333;'>Utiliza el siguiente código para iniciar sesión en tu cuenta:</p>
                
                <div style='font-size: 42px; font-weight: bold; letter-spacing: 8px; color: #FD7C36; margin: 30px 0; border: 2px dashed #FD7C36; padding: 15px; display: inline-block;'>
                    $code
                </div>
                
                <p style='font-size: 14px; color: #888888;'>Este código expirará en 10 minutos. Si no solicitaste este acceso, puedes ignorar este correo.</p>
            </div>
            
            <div style='text-align: center; font-size: 12px; color: #AAAAAA; margin-top: 30px;'>
                &copy; " . date('Y') . " Join App. Conecta con gente real.
            </div>
        </div>
        ";
    }
}
