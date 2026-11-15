<?php
/**
 * Plugin Name: Local Staging
 * Description: Mails ins lokale Mailpit umleiten, Suchmaschinen aussperren, Hinweis in der Admin-Leiste.
 */

// Alle ausgehenden Mails an Mailpit (http://localhost:8025) statt an echte Empfaenger.
add_action('phpmailer_init', function ($phpmailer) {
    $phpmailer->isSMTP();
    $phpmailer->Host = 'mailpit';
    $phpmailer->Port = 1025;
    $phpmailer->SMTPAuth = false;
    $phpmailer->SMTPSecure = '';
    $phpmailer->SMTPAutoTLS = false;
});

// Suchmaschinen aussperren.
add_filter('pre_option_blog_public', '__return_zero');

// Sichtbarer Hinweis, damit Staging nicht mit Live verwechselt wird.
add_action('admin_bar_menu', function ($bar) {
    $bar->add_node(['id' => 'local-staging', 'title' => 'LOCAL STAGING', 'href' => false]);
}, 1);
$staging_css = function () {
    echo '<style>#wp-admin-bar-local-staging{background:#c0392b!important}</style>';
};
add_action('wp_head', $staging_css);
add_action('admin_head', $staging_css);
